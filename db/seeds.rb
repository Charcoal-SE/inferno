# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

#PostType.create(:name => 'questions', :ws => 'questions-active', :route => '/questions', :allocation => 7000)
PostType.create(:name => 'comments', :ws => nil, :route => '/comments', :allocation => 3000)