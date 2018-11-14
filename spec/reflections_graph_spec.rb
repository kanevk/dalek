class Dalek
  RSpec.describe ReflectionsGraph do
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
        has_many :posts
        has_many :comments
        has_many :commented_posts, through: :comments, source: :post

        has_many :child_users, class_name: 'User', foreign_key: :parent_user_id
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
      # Object.send :remove_const, 'Comment'
      # Object.send :remove_const, 'Post'
      # Object.send :remove_const, 'User'
      # Object.send :remove_const, 'Avatar'
    end

    it '#create_reverse_reflection' do
      graph = ReflectionsGraph.new(User)
      belongs_to_reflection = Avatar.reflect_on_association(:user)
      reflection = graph.create_reverse_reflection(User, belongs_to_reflection)

      expect(reflection).to have_attributes(foreign_key: 'user_id',
                                            table_name: 'avatars',
                                            active_record: User,
                                            klass: Avatar)
    end

    it '#reflections' do
      graph = ReflectionsGraph.new(User)
      expect(graph.reflections.map { |r| r.table_name.to_sym }). to contain_exactly(
        :posts, :comments, :users, :avatars
      )
    end
  end
end
