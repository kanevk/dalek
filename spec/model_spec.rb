# frozen_string_literal: true

RSpec.describe Dalek do
  def connection
    ActiveRecord::Base.connection
  end

  before(:all) do
    connection.create_table :countries do |t|
      t.string :name

      t.timestamps null: false
    end

    connection.create_table :users do |t|
      t.string :name, index: {unique:  true}, null: false
      t.belongs_to :parent_user, foreign_key: {to_table: :users}
      t.belongs_to :country, foreign_key: true, null: false

      t.timestamps null: false
    end

    connection.create_table :avatars do |t|
      t.text :content
      t.belongs_to :user, foreign_key: true, null: false

      t.timestamps null: false
    end

    connection.create_table :posts do |t|
      t.string :title
      t.belongs_to :user, foreign_key: true, null: false

      t.timestamps null: false
    end

    connection.create_table :comments do |t|
      t.string :body
      t.belongs_to :user, foreign_key: true, null: false
      t.belongs_to :post, foreign_key: true, null: false

      t.timestamps null: false
    end

    ActiveRecord::SchemaDumper.dump connection
  end

  after(:all) do
    connection.drop_table :comments
    connection.drop_table :posts
    connection.drop_table :avatars
    connection.drop_table :users
    connection.drop_table :countries
  end

  before do
    class Country < ActiveRecord::Base
    end

    class User < ActiveRecord::Base
      has_many :posts
      has_many :comments
      has_many :commented_posts, through: :comments, source: :post

      has_many :child_users, class_name: 'User', foreign_key: :parent_user_id

      belongs_to :country
    end

    class Comment < ActiveRecord::Base
      belongs_to :post
      belongs_to :user
    end

    class Post < ActiveRecord::Base
      has_many :comments

      belongs_to :user
    end

    class Avatar < ActiveRecord::Base
      belongs_to :user
    end
  end

  after do
    Object.send :remove_const, 'Comment'
    Object.send :remove_const, 'Post'
    Object.send :remove_const, 'User'
    Object.send :remove_const, 'Avatar'
    Object.send :remove_const, 'Country'
  end

  id = 0
  increment_default = ->(value) { "#{value}-#{id+=1}" }
  DF = increment_default

  def create_comment(save: true, **attrs)
    attrs[:user] ||= create_user save: save, name: DF.call('Commentator')
    attrs[:post] ||= create_post save: save

    Comment.new(**attrs).tap do |model|
      model.save! if save
      yield model if block_given?
    end
  end

  def create_post(save: true, **attrs)
    attrs[:user] ||= create_user save: save, name: DF.call('Author')
    attrs[:title] ||= DF.call('Title')

    Post.new(**attrs).tap do |model|
      model.save! if save
      yield model if block_given?
    end
  end

  def create_avatar(save: true, **attrs)
    Avatar.new(**attrs).tap do |model|
      model.save! if save
      yield model if block_given?
    end
  end

  def create_user(save: true, **attrs)
    attrs[:name] ||= DF.call('Default User')
    attrs[:country] ||= Country.create name: DF.call('Some-countria')

    User.new(**attrs).tap do |model|
      model.save! if save
      yield model if block_given?
    end
  end

  def create_complex_user(**attrs)
    create_user(
      {
        comments: [create_comment(save: false)],
        posts: [create_post(save: false)],
      }.merge(attrs)
    ) do |user|
      create_avatar user_id: user.id
    end
  end

  def build_delete_user_service(deletion_tree = nil, &block)
    Class.new(Dalek) do
      delete :users, deletion_tree, &block
    end
  end

  context 'when using data structure deletion schema' do
    describe 'the handler' do
      it 'deletes the records by default' do
        user = create_user

        build_delete_user_service({}).exterminate user

        expect { user.reload }.to raise_error ActiveRecord::RecordNotFound
      end

      it 'skips the records with :skip handler' do
        user = create_user

        build_delete_user_service(:skip).exterminate user

        expect(user.reload).to be_present
      end

      it 'deletes the associated records through has_many relation' do
        user = create_user
        comment = create_comment user: user

        build_delete_user_service(comments: :delete).exterminate user

        expect { comment.reload }.to raise_error ActiveRecord::RecordNotFound
      end

      it 'deletes the associated records through hidden association' do
        user = create_user
        avatar = create_avatar user_id: user.id

        build_delete_user_service([:avatars, foreign_key: :user_id] => :delete).exterminate user

        expect { avatar.reload }.to raise_error ActiveRecord::RecordNotFound
      end

      it 'works with custom handler' do
        user = create_user
        expected_user = nil
        handler = ->(fetched_users) { expected_user = fetched_users.first }

        build_delete_user_service(_handler: handler).exterminate user

        expect(user).to eq expected_user
      end

      it 'works with custom handler for inner tables' do
        user = create_user
        posts = [create_post(user: user), create_post(user: user)]
        expected_posts = nil
        posts_handler = ->(fetched_posts) { expected_posts = fetched_posts }

        build_delete_user_service(posts: posts_handler, _handler: :skip).exterminate user

        expect(posts.map(&:id)).to match_array(expected_posts.map(&:id))
      end

      it 'works with associations to own table' do
        grand_user = create_user
        user = create_user(parent_user_id: grand_user.id)
        child_users = [create_user(parent_user_id: user.id)]
        expected_users = nil
        inner_handler = ->(fetched_users) { expected_users = fetched_users.to_a }

        build_delete_user_service(child_users: inner_handler, _handler: :skip).exterminate user

        expect(child_users.map(&:id)).to match_array(expected_users.map(&:id))
      end

      it 'works with belongs to associations' do
        country = Country.new(name: :name)
        user = create_user country: country

        # TODO: Find better way to use belongs to associations!
        handler = lambda do |countries|
          countries_ids = countries.ids
          User.where(country: countries_ids).delete_all
          Country.where(id: countries_ids).delete_all
        end

        build_delete_user_service(countries: handler, _handler: :skip).exterminate user

        expect { country.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe 'before callbacks' do
      it 'triggers before callback' do
        user = create_user
        remote_api = double call: nil

        expect(remote_api).to receive(:call)

        build_delete_user_service(_before: remote_api.method(:call)).exterminate user
      end

      it "doesn't delete the record if before callback returns false value" do
        user = create_user

        build_delete_user_service(_before: ->(_) { false }).exterminate user

        expect { user.reload }.not_to raise_error
      end
    end
  end

  context 'when using DSL deletion schema' do
    describe 'the handler' do
      it 'deletes the records by default' do
        user = create_user

        build_delete_user_service() {}.exterminate user

        expect { user.reload }.to raise_error ActiveRecord::RecordNotFound
      end

      it 'skips the records with :skip handler' do
        post = create_post

        build_delete_user_service do
          on_resolve(&:itself)
          skip :posts
        end.exterminate post.user

        expect(post.reload).to be_present
      end

      it 'deletes the associated records through has_many relation' do
        user = create_user
        comment = create_comment user: user

        build_delete_user_service { delete :comments }.exterminate user

        expect { comment.reload }.to raise_error ActiveRecord::RecordNotFound
      end

      it 'deletes the associated records through hidden association' do
        user = create_user
        avatar = create_avatar user_id: user.id

        build_delete_user_service { delete :avatars, foreign_key: :user_id }.exterminate user

        expect { avatar.reload }.to raise_error ActiveRecord::RecordNotFound
      end

      it "works with 'on_resolve' handler" do
        user = create_user
        expected_user = nil

        build_delete_user_service do
          on_resolve { |fetched_users| expected_user = fetched_users.first }
        end.exterminate user

        expect(user).to eq expected_user
      end

      it 'works with custom handler for inner tables' do
        user = create_user
        posts = [create_post(user: user), create_post(user: user)]
        expected_posts = nil

        build_delete_user_service do
          on_resolve(&:itself)
          resolve(:posts) { |fetched_posts| expected_posts = fetched_posts }
        end.exterminate user

        expect(posts.map(&:id)).to match_array(expected_posts.map(&:id))
      end

      it 'works with associations to own table' do
        grand_user = create_user
        user = create_user(parent_user_id: grand_user.id)
        child_users = [create_user(parent_user_id: user.id)]
        expected_users = nil

        build_delete_user_service do
          on_resolve(&:itself)
          resolve(:child_users) { |fetched_users| expected_users = fetched_users.to_a }
        end.exterminate user

        expect(child_users.map(&:id)).to match_array(expected_users.map(&:id))
      end

      it 'works with belongs to associations' do
        country = Country.new(name: :name)
        user = create_user country: country

        build_delete_user_service do
          on_resolve(&:itself)
          # TODO: Find better way to use belongs to associations!
          resolve :countries do |countries|
            countries_ids = countries.ids
            User.where(country: countries_ids).delete_all
            Country.where(id: countries_ids).delete_all
          end
        end.exterminate user

        expect { country.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe 'before callbacks' do
      it 'triggers before callback' do
        user = create_user
        remote_api = double call: nil

        expect(remote_api).to receive(:call)

        build_delete_user_service { before { remote_api.call } }.exterminate user
      end

      it "doesn't delete the record if before callback returns false value" do
        user = create_user

        build_delete_user_service { before { false } }.exterminate user

        expect { user.reload }.not_to raise_error
      end
    end

    describe 'after callbacks' do
      it 'triggers with correct scope' do
        user = create_user
        expected_user_id = user.id
        fetched_user_id = nil

        build_delete_user_service do
          after { |users| fetched_user_id = users.first.id }
        end.exterminate user

        expect(fetched_user_id).to eq expected_user_id
      end
    end

    describe 'scope options' do
      it "deletes only records matched by the 'where' hash" do
        user = create_user
        post = create_post(user: user, title: 'title')

        build_delete_user_service do
          delete :posts, where: {title: 'title'}
        end.exterminate user

        expect { post.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "doesn't delete records not matched by the 'where' hash" do
        user = create_user
        post = create_post(user: user, title: 'title')

        build_delete_user_service do
          on_resolve(&:itself)
          delete :posts, where: {title: 'different title'}
        end.exterminate user

        expect { post.reload }.not_to raise_error
      end

      it "finds the records matched by the 'where' hash" do
        user = create_user
        post = create_post(user: user, title: 'title')
        fetched_post_id = nil

        build_delete_user_service do
          on_resolve(&:itself)
          resolve :posts, where: {title: 'title'} do |posts|
            fetched_post_id = posts.first.id
          end
        end.exterminate user

        expect(fetched_post_id).to eq post.id
      end

      it "skips the records matched by the 'where_not' hash" do
        user = create_user
        create_post(user: user, title: 'title')

        fetched_posts = nil

        build_delete_user_service do
          on_resolve(&:itself)
          resolve :posts, where_not: {title: 'title'} do |posts|
            fetched_posts = posts
          end
        end.exterminate user

        expect(fetched_posts).to eq []
      end
    end
  end
end
