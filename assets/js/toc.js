document.addEventListener('DOMContentLoaded', function() {
  var SCROLL_OFFSET = document.querySelector('.index.sticky-nav') ? -118 : -58;

  document.querySelectorAll('.index.sticky-nav').forEach(function(el){
    // ScrollSpy has trouble determining the scroll offset for sticky elements that have already been scrolled past because they stick to the top: so their scrollTop is 0 instead of where the elem is actually in the window. so, here, split those elements apart to make it work, more-better. 
    var indexAnchor = document.createElement(el.nodeName);
    indexAnchor.classList.add('index');
    indexAnchor.setAttribute('id', el.getAttribute('id'));
    indexAnchor.innerHTML = '&nbsp;';
    el.classList.remove('index');
    el.setAttribute('id', undefined);
    el.parentNode.insertBefore(indexAnchor, el);
  });
  
  var tocHeader = document.getElementById('toc-header');
  if(tocHeader && PAGE_TOC){
    var navIndexHeading = document.createElement("li"); 
    navIndexHeading.classList.add('nav-index-heading');
    var navIndexHeadingContent = document.createTextNode(PAGE_TOC); 
    var navIndexBackToTop = document.createElement('span')
    navIndexBackToTop.innerHTML = '<a class="btn-floating btn-small btn-flat waves-effect waves-light nav-back-to-top tooltipped" data-tooltip="Back to top"><i class="material-icons">arrow_upward</i></a>';
    navIndexHeading.appendChild(navIndexHeadingContent);
    navIndexHeading.appendChild(navIndexBackToTop);
    tocHeader.appendChild(navIndexHeading);
    document.querySelector('.nav-back-to-top').addEventListener('click', function(e){
      document.querySelector('#slide-out').scrollTo(0,0);
    });
  }
  
  var items = [];
  document.querySelectorAll('.index').forEach(function(el){
    items.push('<li><a href="#'+el.id+'"'+' class="waves-effect sidenav-close">'+el.id+'</a></li>');
  });

  var navUl = document.querySelector('#scrollspy-nav ul');
  if(navUl){
    navUl.innerHTML = items.join('');
    navUl.classList.remove('hidden');
  }

  var scrollSpyEnter = function(navElemSelector, id){
    var scrollspyNavElem = document.querySelector('#scrollspy-nav');
    var navElem = scrollspyNavElem.querySelector(navElemSelector);
    scrollspyNavElem.querySelectorAll('.active').forEach(function(el){
      el.classList.remove('active');
    })
    if(navElem){
      navElem.classList.add('active');
      document.querySelector('#slide-out').scrollTo(window.scrollX, navElem.offsetTop - scrollspyNavElem.offsetTop)
    }
  }

  var debounceScrollSpyEnter = debounce(scrollSpyEnter, 100);
  M.ScrollSpy.init(document.querySelectorAll('.index'), {
    scrollOffset: SCROLL_OFFSET,
    getActiveElement: function(id){
      var navElemSelector = 'a[href="#' + id + '"]';
      debounceScrollSpyEnter(navElemSelector, id);
      return navElemSelector;
    }
  });

});
