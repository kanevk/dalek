# frozen_string_literal: true

RSpec.describe Dalek do
  def connection
    ActiveRecord::Base.connection
  end

  before(:all) do
    connection.create_table :users do |t|
      t.string :name, index: {unique:  true}, null: false
      t.belongs_to :parent_user, foreign_key: {to_table: :users}

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
  end

  before do
    class User < ActiveRecord::Base
      extend Dalek::Spy

      has_many :posts
      has_many :comments
      has_many :commented_posts, through: :comments, source: :post

      has_many :child_users, class_name: 'User', foreign_key: :parent_user_id

      hidden_association :has_many, :avatars
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
    end
  end

  after do
    Object.send :remove_const, 'Comment'
    Object.send :remove_const, 'Post'
    Object.send :remove_const, 'User'
    Object.send :remove_const, 'Avatar'
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

  def build_delete_user_service(deletion_tree = {})
    Class.new do
      include Dalek::Exterminate

      extermination_plan 'User', deletion_tree
    end
  end

  describe 'the handler' do
    it 'deletes the records by default' do
      user = create_user

      build_delete_user_service.execute user

      expect { user.reload }.to raise_error ActiveRecord::RecordNotFound
    end

    it 'skips the records with :skip handler' do
      user = create_user

      build_delete_user_service(:skip).execute user

      expect(user.reload).to be_present
    end

    it 'deletes the associated records through has_many relation' do
      user = create_user
      comment = create_comment user: user

      build_delete_user_service(comments: :delete).execute user

      expect { comment.reload }.to raise_error ActiveRecord::RecordNotFound
    end

    it 'deletes the associated records through hidden association' do
      user = create_user
      avatar = create_avatar user_id: user.id

      build_delete_user_service(avatars: :delete).execute user

      expect { avatar.reload }.to raise_error ActiveRecord::RecordNotFound
    end

    it 'works with custom handler' do
      user = create_user
      expected_user = nil
      handler = ->(fetched_users) { expected_user = fetched_users.first }

      build_delete_user_service(_handler: handler).execute user

      expect(user).to eq expected_user
    end

    it 'works with custom handler for inner tables' do
      user = create_user
      posts = [create_post(user: user), create_post(user: user)]
      expected_posts = nil
      posts_handler = ->(fetched_posts) { expected_posts = fetched_posts }

      build_delete_user_service(posts: posts_handler, _handler: :skip).execute user

      expect(posts.map(&:id)).to match_array(expected_posts.map(&:id))
    end

    it 'works with associations to own table' do
      user = create_user
      child_users = [create_user(parent_user_id: user.id)]
      expected_users = nil
      inner_handler = ->(fetched_users) { expected_users = fetched_users }

      build_delete_user_service(child_users: inner_handler, _handler: :skip).execute user


      expect(child_users.map(&:id)).to match_array(expected_users.map(&:id))
    end
  end

  describe 'before callbacks' do
    it 'triggers before callback' do
      user = create_user
      remote_api = double call: nil

      expect(remote_api).to receive(:call)

      build_delete_user_service(_before: remote_api.method(:call)).execute user
    end

    it "doesn't delete the record if before callback return falsy value" do
      user = create_user

      build_delete_user_service(_before: ->(_) { nil }).execute user

      expect { user.reload }.not_to raise_error
    end
  end
end
