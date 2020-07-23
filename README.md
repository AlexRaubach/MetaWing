# MetaWing

An application that takes the wealth of data from List Fortress, and tries to
distill it down into a number of reports that answer questions the community might
have.

## Application Stack

The application is written in Ruby on Rails and uses PostgreSQL as its database.

Preferably, use something like Rbenv to handle your Rubies and Gemsets. Then checkout
the repository (including the submodule), make sure you're using [the Ruby version found here](.ruby-version) and have
Postgres installed, and...

```bash
cp config/database.yml.example config/database.yml
bundle
rake db:create db:migrate db:seed
```

...and done. If you're developing on Windows, 
install the Linux for Windows subsystem and use that to install and manage dependancies. 

I have a [guide I wrote for ListFortress](https://github.com/AlexRaubach/ListFortress/blob/master/Setup.md) about setting up and developing on WSL that covers everything you need to get started. 

Importing all the data (takes a while):

```bash
rake sync:enable sync:xwing_data2 sync:tournaments sync:rebuild_rankings sync:disable
```

For updates later (updates everything):

```bash
rake sync:tournaments[<min_id>,<min_date>]
rake sync:rebuild_rankings[<min_id>,<min_date>]
```
Both parameters are optional for both rake tasks, just skip the brackets if you
don't want to provide them.

Also see, [the Changelog](CHANGELOG.md) (which is also displayed in the online application)
