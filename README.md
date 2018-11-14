# dalek
The exterminator of application records. #GDPR

![The price](dalek.jpg)

# Installation

~~gem install dalek~~

But not yet! To be uploaded...

# Usage

Describing the deletions as a data structure
```ruby
class DeleteUser < Dalek
  deletion_tree 'User', {
    _before: ->(users) { users.none(&:active?) },
    posts: {
      comments: {commented_posts: :delete},
    },
    comments: :delete,
    avatars: ->(avatars) { avatars.update!(user_id: nil, image: nil) },
  }
end
```

Extermination
```ruby
  user = User.find_by doomed: true

  DeleteUser.execute user # => true/false result, paraphrased Ta-da
```


# Related materials
http://nithinbekal.com/posts/ruby-tco/
https://robots.thoughtbot.com/referential-integrity-with-foreign-keys
