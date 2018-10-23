# dalek
The exterminator of application records. #GDPR

![The price](dalek.jpg)

# Installation

~~gem install dalek~~

But not yet! To be uploaded...

# Usage

Describing the deletions as a data structure
```ruby
class DeleteUser < Dalek::Exterminate
  deletion_tree '', {
    _before: lambda { @target.active? },
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


# Materials
http://nithinbekal.com/posts/ruby-tco/
https://robots.thoughtbot.com/referential-integrity-with-foreign-keys
