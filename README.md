
# Tweetcode

Tweetcode allows to post code snippets to twitter via Travis CI.

## Contribution Flow

Follow steps below to "push" some code snippets to Twitter.

### Setup local repo (fist time only)

1. Fork this repo and clone it
2. Run `git config --local include.path ../.gitconfig`

### Add your snippet

1. Create a new branch based on master
2. Create new file with code snippet in `snippets` directory:
   1. Give it meaningful name
   2. Make sure it's `UTF-8`-encoded file
3. Commit your changes
   1. Commit message must follow specific format (template provided)
4. Run `make` to preview generated tweet
   1. If there is no errors it'll print generated tweet text and name of
      generated image
4. Push your changes
6. Open Pull Request
   1. In case of failed CI build - fix locally, squash and push again
7. After PR is being merged to master, new snippet will be automatically
   published to twitter


## CI Setup

Follow steps below to setup your own Tweetcode.

1. Mirror this repository (don't fork)
   1. Go to github.com and sign in
   2. Click on "+" sign
   3. Select "Import repository"
   4. Set https://github.com/josephbuchma/tweetcode for "Your old repository’s clone URL" field
   5. Set name for your repository and click on "Begin import" button.
2. Clone your newly created repo
3. Edit `.travis.yml` (provided `.travis.yml` is example Golang setup)
   1. *Note*: Travis CI has Nodejs and Ruby (both required by Tweetcode)
      installed by default, regardless what is the `language` in your
      `.travis.yml`
4. Commit your changes to master branch with `[skip ci]` tag in commit message (e.g.
   `Reconfigured .travis.yml [no ci]`)
5. Setup your [twitter command line
   tool](https://github.com/sferik/t#configuration) locally
   for your tweetcode twitter account
6. Make sure you have [travis CLI
   installed](https://github.com/travis-ci/travis.rb#installation)
7. Enable Travis CI for this repo (through web interface or by running `travis enable`)
10. Set environment variables for CI (look inside `~/.trc` file for values):
   1. Set `TWITTER_CONSUMER_KEY`, `TWITTER_CONSUMER_SECRET`, `TWITTER_ACCESS_TOKEN` and `TWITTER_ACCESS_SECRET` environment variables
      (e.g. `travis env set TWITTER_CONSUMER_KEY my-twitter-consumer-key`)

After that follow *Contribution flow* described above.

## License

MIT
