document.addEventListener('DOMContentLoaded', function () {
  var SCROLL_OFFSET = document.querySelector('.index.sticky-nav') ? -118 : -58;

  document.querySelectorAll('.index.sticky-nav').forEach(function (el) {
    // ScrollSpy has trouble determining the scroll offset for sticky elements that have already been scrolled past because they stick to the top: so their scrollTop is 0 instead of where the elem is actually in the window. so, here, split those elements apart to make it work, more-better. 
    var indexAnchor = document.createElement(el.nodeName);
    indexAnchor.classList.add('index');
    indexAnchor.setAttribute('id', el.getAttribute('id'));
    indexAnchor.innerHTML = '&nbsp;';
    el.classList.remove('index');
    el.removeAttribute('id');
    el.parentNode.insertBefore(indexAnchor, el);
  });

  var tocHeader = document.getElementById('toc-header');
  if (tocHeader && PAGE_TOC) {
    var navIndexHeading = document.createElement("li");
    navIndexHeading.classList.add('nav-index-heading');
    var navIndexHeadingContent = document.createTextNode(PAGE_TOC);
    var navIndexBackToTop = document.createElement('span')
    navIndexBackToTop.innerHTML = '<a class="btn-floating btn-small btn-flat waves-effect waves-light nav-back-to-top tooltipped" data-tooltip="Back to top"><i class="material-icons">arrow_upward</i></a>';
    navIndexHeading.appendChild(navIndexHeadingContent);
    navIndexHeading.appendChild(navIndexBackToTop);
    tocHeader.appendChild(navIndexHeading);
    document.querySelector('.nav-back-to-top').addEventListener('click', function (e) {
      document.querySelector('#slide-out').scrollTo(0, 0);
    });
  }

  var items = [];
  document.querySelectorAll('.index').forEach(function (el) {
    items.push('<li><a href="#' + el.id + '"' + ' class="waves-effect sidenav-close">' + el.id + '</a></li>');
  });

  var navUl = document.querySelector('#scrollspy-nav ul');
  if (navUl) {
    navUl.innerHTML = items.join('');
    navUl.classList.remove('hidden');
  }

  var scrollSpyEnter = function (navElemSelector, id) {
    var scrollspyNavElem = document.querySelector('#scrollspy-nav');
    var navElem = scrollspyNavElem.querySelector(navElemSelector);
    scrollspyNavElem.querySelectorAll('.active').forEach(function (el) {
      el.classList.remove('active');
    })
    if (navElem) {
      navElem.classList.add('active');
      document.querySelector('#slide-out').scrollTo(window.scrollX, navElem.offsetTop - scrollspyNavElem.offsetTop)
    }
  }

  var debounceScrollSpyEnter = debounce(scrollSpyEnter, 100);
  M.ScrollSpy.init(document.querySelectorAll('.index'), {
    scrollOffset: SCROLL_OFFSET,
    getActiveElement: function (id) {
      var navElemSelector = 'a[href="#' + id + '"]';
      debounceScrollSpyEnter(navElemSelector, id);
      return navElemSelector;
    }
  });

  // odang! try to create hyperlinkz for "see also"
  try {
    var see = document.evaluate("//em[contains(., 'see')]", document, null, XPathResult.ANY_TYPE, null);
    var seez = see.iterateNext();
    var tagzToUpdate = [];
    while (seez) {
      var txt = seez.nextSibling.textContent;
      var tags = [];
      // split(/,|;/) 
      if (/;/.test(txt)) {
        tags = txt.split(';');
      } else {
        tags = txt.split(',');
      }
      for (var i = 0; i < tags.length; i++) {
        var tag = tags[i].trim();
        if (tag !== '') {
          var found = document.evaluate("//p[starts-with(., '" + tag + " ')]", document, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null).snapshotLength;
          if (found > 0) {
            var tagLinkz = document.evaluate("//p[starts-with(., '" + tag + " ')]", document, null, XPathResult.ANY_TYPE, null);
            var tagLink = tagLinkz.iterateNext();
            if (tagLink) {
              var parentEl = seez.parentElement;
              parentEl && tagzToUpdate.push({ tag: tag, parentEl: parentEl, offsetTop: tagLink.offsetTop });
            }
          }
        }
      } // end for loop
      seez = see.iterateNext();
    } // end while
    // need to defer dom mutationz until after iterating through all the see XPath itemz...
    for (var i = 0; i < tagzToUpdate.length; i++) {
      var tag = tagzToUpdate[i].tag;
      var parentEl = tagzToUpdate[i].parentEl;
      var offsetTop = tagzToUpdate[i].offsetTop;
      // regex with boundry \b to match whole word (avoid removing 'god' from 'goddess')
      tagRegEx = new RegExp('\\b'+tag+'\\b');
      // walk the childNodes to check for text nodes (nodeType 3) 
      // to avoid parentEl.innerHTML.replace which would replace html attributes that may contain the tag...
      // also avoid replacing the first (i==0) match
      parentEl.childNodes.forEach(function (n, i) {
        if (i !== 0 && n.nodeType === 3 && n.textContent.match(tagRegEx)) {
          var tagLink = document.createElement('a');
          tagLink.classList.add('see-scroll');
          tagLink.setAttribute('data-scroll', offsetTop);
          // try to keep comma
          tagLink.innerText = n.textContent.indexOf(tag + ',') > -1 ? tag + ',' : tag;
          n.textContent = n.textContent.replace(tag + ',', '').replace(tagRegEx, '');
          parentEl.insertBefore(tagLink, n);
        }
      });
    }

    var seeScrollClick = function (e) {
      var offsetTop = e.target.getAttribute('data-scroll');
      !isNaN(parseInt(offsetTop)) && window.scrollTo(window.scrollX, parseInt(offsetTop) + SCROLL_OFFSET);
    }
    document.querySelectorAll('.see-scroll').forEach(function (el) {
      el.addEventListener('click', seeScrollClick);
    });
  } catch (e) { /* eh... */ }

});
