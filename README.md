---
layout: default
title: README
permalink: /README.md/
---
## EmergencyINDEX

[![Gitter](https://badges.gitter.im/emergencyindex/community.svg)](https://gitter.im/emergencyindex/community?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

Edit files using a web browser with the [editor on GitHub](https://github.com/emergencyindex/emergencyindex.com/edit/master/README.md)

Whenever there are commits to this repository, GitHub Pages will run [Jekyll](https://jekyllrb.com/) to rebuild the site (_limit of 10 builds an hour_). 

### Markdown Syntax

Markdown is a lightweight and easy-to-use syntax for styling text.

```markdown
# Header 1
## Header 2
### Header 3

- Bulleted
- List

1. Numbered
2. List

**Bold** and _Italic_ and `Code` text

[Link](https://emergencyindex.com) and ![Image](https://emergencyindex.com/assets/img/preview.png)

> blockquote

two spaces  
after text  
will not
add return

Header 0 | Header 1
-------- | --------
cell 1 | cell 2
cell 3 | cell 4

HTML
<dl>
  <dt>Definition list</dt>
  <dd>Is something people use sometimes.</dd>

  <dt>Markdown in HTML</dt>
  <dd>Does *not* work **very** well. Use HTML <em>tags</em>.</dd>
</dl>

Horizontal Rule

---

```

The above markdown code looks like:

# Header 1
## Header 2
### Header 3

- Bulleted
- List

1. Numbered
2. List

**Bold** and _Italic_ and `Code` text

[Link](https://emergencyindex.com) and ![Image](https://emergencyindex.com/assets/img/preview.png)

> blockquote

two spaces  
after text  
will not
add return (and multiple line breaks are ignored!)

Header 0 | Header 1
-------- | --------
cell 1 | cell 2
cell 3 | cell 4

HTML
<dl>
  <dt>Definition list</dt>
  <dd>Is something people use sometimes.</dd>

  <dt>Markdown in HTML</dt>
  <dd>Does *not* work **very** well. Use HTML <em>tags</em>.</dd>
</dl>

---

For more details see [GitHub Flavored Markdown](https://guides.github.com/features/mastering-markdown/).

### Project template

All of the project files need to include this [YAML](http://yaml.org/) metadata at the top of the Markdown file:

```markdown
---
layout: project
volume: 
image: 
photo_credit: 
title: 
first_performed: 
place: 
times_performed: 
contributor: 
collaborators:
  -
home: 
links: 
  - 
contact: 
footnote: 
tags: 
  - 
pages:
needs_review:
---

```

### local development 

#### git stuff 

$ `git clone https://github.com/emergencyindex/emergencyindex.com.git`

the content for each year is referenced via git submodules to individual project repos: 

[projects-2011](https://github.com/emergencyindex/projects-2011),
[projects-2012](https://github.com/emergencyindex/projects-2012),
[projects-2013](https://github.com/emergencyindex/projects-2013),
[projects-2014](https://github.com/emergencyindex/projects-2014),
[projects-2015](https://github.com/emergencyindex/projects-2015),
[projects-2016](https://github.com/emergencyindex/projects-2016)

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


#### Jekyll (for local development)

...to get started make sure ruby 2.4 (or higher version) is installed. see [rvm](https://rvm.io/)

$ `gem install bundler`

$ `bundle install`

$ `bundle exec jekyll serve` 

(...it will take a few minutes to build)

add `--incremental` flag to speed up build time. make changes and preview locally, run:

$ `bundle exec jekyll serve --incremental`
