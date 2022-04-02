+++
title = "Encrypted SQLite With Ecto"
date = "2022-01-21T14:36:40-07:00"
author = "Connor Rigby"
authorTwitter = "PressY4Pie"
cover = ""
tags = ["elixir", "ecto", "sqlite"]
keywords = ["elixir", "database", "encryption"]
description = "Database level encryption backed by SQLCipher"
+++

# TLDR

Compiling SQLCipher:

```bash
./configure \
  --enable-tempstore=yes \
  --disable-tcl \
  --enable-shared \
  CFLAGS="-DSQLITE_HAS_CODEC -DSQLITE_THREADSAFE=1 -DSQLITE_USE_URI=1 -DSQLITE_LIKE_DOESNT_MATCH_BLOBS=1 -DSQLITE_DQS=0 -DHAVE_USLEEP=1 -DALLOW_COVERING_INDEX_SCAN=1 -DENABLE_FTS3_PARENTHESIS=1 -DENABLE_LOAD_EXTENSION=1 -DENABLE_SOUNDEX=1 -DENABLE_STAT4=1 -DENABLE_UPDATE_DELETE_LIMIT=1 -DSQLITE_ENABLE_FTS3=1 -DSQLITE_ENABLE_FTS4=1 -DSQLITE_ENABLE_FTS5=1 -DSQLITE_ENABLE_GEOPOLY=1 -DSQLITE_ENABLE_JSON1=1 -DSQLITE_ENABLE_MATH_FUNCTIONS=1 -DSQLITE_ENABLE_RBU=1 -DSQLITE_ENABLE_RTREE=1 -DSQLITE_OMIT_DEPRECATED=1" \
  LDFLAGS="-lcrypto"
```

# Encrypting SQLite Databases

SQLite is one of my favorite pieces of software in the world. It's used in millions
of projects and devices. One issue with the official public version of it is that
there is no support for encryption natively. The primary decision for this seems to be
for monetizing the work of the developers. 

What this means is that to encrypt your SQLite database, you actually have to recompile
the entire engine from source, with licensed files. You can read more about the
official SQLite encryption [on the official website](https://www.sqlite.org/see/doc/trunk/www/readme.wiki)

An alternative option to SQLite encryption that is free and open source is [SQLCipher](https://www.zetetic.net/sqlcipher/).
It implements a similar API and to the offical SEE release, and also requires you to compile the engine from source.

## Compiling SQLCipher

This is the most time consuming part of the process. Luckily it only needs to be done once. 

    NOTE: this is specifically for your development environment. Compiling for production 
          *may* look the same to you, but it may not. This is specifically a problem for Nerves
          which I will write a follow-up post about in the future.

The first step for compiling SQLCipher is getting the source. I chose to use the latest tagged release,
a git clone will work the same.

```bash
wget https://github.com/sqlcipher/sqlcipher/archive/refs/tags/v4.5.0.tar.gz
tar xzf v4.5.0.tar.gz
cd sqlcipher-4.5.0
```

Next up, use autotools to configure the build. These are the settings I suggest starting with:

```bash
./configure \
  --enable-tempstore=yes \
  --disable-tcl \
  --enable-shared \
  CFLAGS="-DSQLITE_HAS_CODEC -DSQLITE_THREADSAFE=1 -DSQLITE_USE_URI=1 -DSQLITE_LIKE_DOESNT_MATCH_BLOBS=1 -DSQLITE_DQS=0 -DHAVE_USLEEP=1 -DALLOW_COVERING_INDEX_SCAN=1 -DENABLE_FTS3_PARENTHESIS=1 -DENABLE_LOAD_EXTENSION=1 -DENABLE_SOUNDEX=1 -DENABLE_STAT4=1 -DENABLE_UPDATE_DELETE_LIMIT=1 -DSQLITE_ENABLE_FTS3=1 -DSQLITE_ENABLE_FTS4=1 -DSQLITE_ENABLE_FTS5=1 -DSQLITE_ENABLE_GEOPOLY=1 -DSQLITE_ENABLE_JSON1=1 -DSQLITE_ENABLE_MATH_FUNCTIONS=1 -DSQLITE_ENABLE_RBU=1 -DSQLITE_ENABLE_RTREE=1 -DSQLITE_OMIT_DEPRECATED=1" \
  LDFLAGS="-lcrypto"
```

And finally, you just need to:

```bash
make
# May require root permissions
make install
```

## Setup with Ecto

Right before this post went live, I submitted two PRs to the Elixir SQLite driver:

* https://github.com/elixir-sqlite/exqlite/pull/186
* https://github.com/elixir-sqlite/exqlite/pull/187

The first allows for using externally compiled SQLite engine. This is required to use our
previously compiled SQLCipher engine. 

The second allows for setting the `KEY` PRAGMA value. This is what SQLite SEE and SQLCipher
both use to decrypt data. It must be supplied before *any* of the SQLite database will be
accessable. 

To have access to these new features, you will need to update to the latest version of `exqlite`.
Add `{:exqlite "~> 0.9"}` to your project, or simply update it with:

```bash
mix deps.update exqlite
```

To get `exqlite` to use our SQLCipher installation, you need to export a handful of environment variables:

```
# tell exqlite that we wish to use some other sqlite installation. this will prevent sqlite3.c and friends from compiling
export EXQLITE_USE_SYSTEM=1

# Tell exqlite where to find the `sqlite3.h` file
export EXQLITE_SYSTEM_CFLAGS=-I/usr/local/include/sqlcipher

# tell exqlite which sqlite implementation to use
export EXQLITE_SYSTEM_LDFLAGS=-L/usr/local/lib -lsqlcipher
```

do a recompile with:

```bash
mix deps.compile exqlite --force
```

Almost done, the only other thing you have to do is supply a `key` to the config. In `config.exs` you can do something like:

```elixir
config :my_app,
  ecto_repos: [MyApp.Repo]

config :my_app, MyApp.Repo,
  database: "path/to/my/database.db",
  key: "test123" # add this line
```

And that's it! Your data is now encrypted using the key provided. 