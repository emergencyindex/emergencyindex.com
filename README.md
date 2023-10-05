---
layout: default
title: README
permalink: /README.md/
---

# EmergencyINDEX

## AN ANNUAL DOCUMENT OF PERFORMANCE PRACTICE

[![Gitter](https://badges.gitter.im/emergencyindex/community.svg)](https://gitter.im/emergencyindex/community?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

👋this is a [Jekyll](https://jekyllrb.com/) project for the [EmergencyINDEX.com](http://emergencyindex.com) website. this repository contains code to build a static website leveraging the Jekyll "ruby framework" and a lot of [liquid templates](https://shopify.github.io/liquid/) to generate .html (.js, .json, and .css, too! 😊) files that are hosted (for free! 🙌) via [GitHub Pages](https://github.com/emergencyindex/emergencyindex.com/deployments/activity_log?environment=github-pages)

curious about the future? see: [emergency_index_people](https://github.com/orgs/emergencyindex/teams/emergency_index_people)

...want to help? [reach out on gitter.im/emergencyindex](https://gitter.im/emergencyindex)

**tldr;**

### devel notes

see [MARKDOWN_NOTES.md](MARKDOWN_NOTES.md) for help getting started with markdown.

see [PROJECT_TEMPLATE.md](PROJECT_TEMPLATE.md) (project's **schema**)

Edit files using a web browser with the [editor on GitHub](https://github.com/emergencyindex/emergencyindex.com/edit/master/README.md)

Whenever there are commits to this repository, GitHub Pages will rebuild the site (_limit of 10 builds an hour_).

### local development

#### git stuff

$ `git clone https://github.com/emergencyindex/emergencyindex.com.git`

the content for each year is referenced via git submodules to individual project repos:

[projects-2011](https://github.com/emergencyindex/projects-2011)  
[projects-2012](https://github.com/emergencyindex/projects-2012)  
[projects-2013](https://github.com/emergencyindex/projects-2013)  
[projects-2014](https://github.com/emergencyindex/projects-2014)  
[projects-2015](https://github.com/emergencyindex/projects-2015)  
[projects-2016](https://github.com/emergencyindex/projects-2016)  
[projects-2017](https://github.com/emergencyindex/projects-2017)  
[projects-2018](https://github.com/emergencyindex/projects-2018)

every repository contains separate branches (`projects`, `indexes`, & `images`) with files that end up their own respective folder in this project (e.g. [projects-2011](https://github.com/emergencyindex/projects-2011)'s `indexes` branch files will end up the `_projects/2011` folder).

so to get ALL of the projects git sub-module content run:

$ `git submodule update --init --recursive`

or to get a single sub-module project:

$ `git submodule update --init -- _projects/2011`

...replace `_projects/2011` what a specific sub-module (e.g. `assets/img/2015`)

see [.gitmodules](https://github.com/emergencyindex/emergencyindex.com/blob/master/.gitmodules) file for reference to all the different modules used in this repository.

to pull in updates from sub-modules run:

$ `git submodule sync`
$ `git submodule update --init --recursive --remote`

##### add a new submodule:

$ `git submodule add <url> <path>`

so for example (**vol. 8**):

```sh
git submodule add https://github.com/emergencyindex/projects-2018 _indexes/2018
git submodule add https://github.com/emergencyindex/projects-2018 _projects/2018
git submodule add https://github.com/emergencyindex/projects-2018 assets/img/2018
```

then edit the `.gitmodules` file to specify the branch for each (3) of these submodules (if needed). for example: `branch = indexes`

so something like:

```
[submodule "_indexes/2018"]
path = _indexes/2018
url = https://github.com/emergencyindex/projects-2018
branch = indexes
```

finally run:

$ `git submodule update --init --recursive --remote`

#### Jekyll (for local development)

...to get started make sure ruby 2.4 (or higher version) is installed. see [rvm](https://rvm.io/)

$ `gem install bundler`

$ `bundle install`

$ `bundle exec jekyll serve`

(...it will take a few minutes to build)

note: if getting error about missing `webrick` run:
$ `bundle add webrick`

add `--incremental` flag to speed up build time. make changes and preview locally, run:

$ `bundle exec jekyll serve --incremental`

#### 🔪 `utilz/scrape_indesign.rb` 🔪

$ `gem install nokogiri sanitize carmen`

rough example how this script was used for vol. 8:

```sh
ruby scrape_indesign.rb -i /Users/edwardsharp/Desktop/index8/index8.html -d /Users/edwardsharp/Desktop/index8/out -v 2018 -p

ruby scrape_indesign.rb --infile /Users/edwardsharp/Desktop/index8/terms.html --out /Users/edwardsharp/Desktop/index8/out --volume 2018 --terms --dryrun

ruby scrape_indesign.rb --infile /Users/edwardsharp/Desktop/index8/terms.html --out /Users/edwardsharp/src/github/emergencyindex/projects-2018 --terms

ruby scrape_indesign.rb --infile /Users/edwardsharp/Desktop/index8/terms.html --volume 2018 --termsindex
```

use detox program (`brew install detox` or whatever) rename image files: (-n for dry-run. detox removes bad filename charz)

```sh
detox -rv /Users/edwardsharp/src/github/emergencyindex/projects-2018
```

use imagemagick (`brew install imagemagick` or whatever) to convert png -> jpgz:

```sh
mogrify -format jpg *.png

ruby scrape_indesign.rb --validateimages /Users/edwardsharp/Desktop/index8/out/projects/2018 --validateimagesdir /Users/edwardsharp/src/github/emergencyindex/projects-2018
```

attempt to update projects metadata with submission .csv data:

```sh
ruby ./utilz/scrape_indesign.rb -c
```

validate each project first_performed & times_performed. copies problem .md files to /needs_review/ dir:

```sh
ruby ./utilz/scrape_indesign.rb -P
```

finally, tidy all the .md files:

```sh
ruby scrape_indesign.rb --tidy  /Users/edwardsharp/Desktop/index8/out/projects/2018/
```
