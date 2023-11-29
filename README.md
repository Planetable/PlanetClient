Planet Client Demo

Basic Features:
- [x] Basic authentication
- [x] List all my planets
- [x] List all articles from my planets
- [x] View an article
- [x] Create a planet with avatar
- [x] Create an article for selected planet with attachments support (non-live images only)
- [x] Present API error with alert
- [x] Edit a planet
- [x] Edit an article
- [x] Support basic offline reading
- [x] Add template for offline rendering
- [x] Planet with template options

Next:
- [ ] Preview an article inside writer (with template)
- [ ] Offline writing

## Running Locally

```sh
$ git clone https://github.com/Planetable/PlanetMobile app
$ cd app
# update developer settings, replacing with your Apple Developer Team ID
$ printf "DEVELOPMENT_TEAM = <your team id> \
         \nCODE_SIGN_STYLE = Automatic" > Planet/local.xcconfig
# open in Xcode
$ open Planet.xcodeproj/
```

In Xcode, press run and it should work.
