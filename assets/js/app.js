var BASE_URL = "/";
var data, terms;
var IS_TOUCH_DEVICE = false;

function debounce(func, wait, immediate) {
  var timeout;
  return function () {
    var context = this, args = arguments;
    var later = function () {
      timeout = null;
      if (!immediate) func.apply(context, args);
    };
    var callNow = immediate && !timeout;
    clearTimeout(timeout);
    timeout = window.setTimeout(later, wait);
    if (callNow) func.apply(context, args);
  };
};

var initAutocomplete = function () {
  var dataObj = {};
  var hrefObj = {};

  for (var proj of data) {
    if (proj.title != '') {
      var _key = proj.title;
      if (proj.contributor && proj.contributor !== '') {
        _key = _key + ' -- ' + proj.contributor;
      }
      if (proj.place && proj.place !== '') {
        _key = _key + ' -- ' + proj.place;
      }
      dataObj[_key.trim()] = null;
      hrefObj[_key.trim()] = proj.url;
    }
  }

  M.Autocomplete.init(document.querySelectorAll('input.autocomplete'), {
    data: dataObj,
    limit: 50,
    onAutocomplete: function (val) {
      var projKey = Object.keys(hrefObj).filter(function (i) { return i === val })[0]
      if (projKey && hrefObj[projKey]) {
        window.location = hrefObj[projKey];
      }
    },
    minLength: 1
  });
}

// var setRandoProjectBannerInterval;

var setRandoProjectBanner = function () {
  // if(!setRandoProjectBannerInterval){
  //   setRandoProjectBannerInterval = window.setInterval(setRandoProjectBanner, 5000);
  // }
  var projectBannerLink = document.querySelector('.project-banner-link');
  if (projectBannerLink) {
    var randoProject = data.filter(function (proj) { return !!proj.image })[Math.floor(Math.random() * data.length - 1)];
    // console.log('randoProject:',randoProject)
    // projectBannerLink.href = randoProject.url;
    var _href = randoProject.url.split('/');
    var _page = _href.pop();
    var _vol = _href.pop();
    projectBannerLink.href = '/volume/' + _vol + '#' + _vol + '-' + _page;
    projectBannerLink.title = randoProject.title + ' -- ' + randoProject.contributor;

    var projectBannerElem = document.querySelector('.project-banner-elem');
    projectBannerElem.style.backgroundImage = 'url("/assets/img/' + randoProject.volume + '/' + randoProject.image + '")';
    window.setTimeout(function () { projectBannerElem.classList.add('project-banner-elem-anim'); }, 10);
    // window.setTimeout(function(){projectBannerElem.classList.remove('project-banner-elem-anim');}, 4750);
    projectBannerElem.innerHTML = '';

    var divTitle = document.createElement("div");
    divTitle.innerHTML = randoProject.title;
    projectBannerElem.appendChild(divTitle);

    var divContributor = document.createElement("div");
    divContributor.innerHTML = randoProject.contributor;
    projectBannerElem.appendChild(divContributor);

    var divVolume = document.createElement("div");
    divVolume.innerHTML = randoProject.volume;
    projectBannerElem.appendChild(divVolume);
  }
}

var destroyTooltipz = function () {
  var tooltipElemz = document.querySelectorAll('.tooltipped');
  tooltipElemz.forEach(function (el) {
    try {
      M.Tooltip.getInstance(el).destroy()
    } catch (e) { /* ...eh */ }
  });
  return tooltipElemz;
}

var initTooltip = function () {
  !IS_TOUCH_DEVICE && M.Tooltip.init(destroyTooltipz(), { enterDelay: 250 });
}

window.addEventListener('touchstart', function firstTouch() {
  IS_TOUCH_DEVICE = true;
  destroyTooltipz();
  window.removeEventListener('touchstart', firstTouch, false);
})

var initProjectTagModal = function () {
  var modalz = document.querySelectorAll('.modal:not(.citation)');

  M.Modal.init(modalz, {
    onOpenStart: function (modal, trigger) {
      var tag = trigger.getAttribute('data-tag');
      modal.querySelector('.tag-name').innerHTML = tag;
      if (terms[tag]) {
        var caption = terms[tag].length + " project" + (terms[tag].length != 1 ? "s" : "");
        var badge = document.createElement("span");
        badge.classList.add('badge');
        badge.setAttribute('data-badge-caption', caption);
        modal.querySelector('.tag-name').appendChild(badge);

        var items = [];
        for (var t of terms[tag]) {
          items.push("<a href='" + t.url + "' class='collection-item project-tag'  >" + t.title + " -- " + t.contributor + " <span class='badge'>" + t.volume + "</span></>");
        }
        modal.querySelector('.collection').innerHTML = items.join('');
      }
      modal.querySelectorAll('.project-tag').forEach(function (el) {
        el.onclick = function (e) {
          var modalInstance = M.Modal.getInstance(modal);
          try {
            var _href = this.getAttribute('href').split('/');
            var _page = _href.pop();
            var _vol = _href.pop();
            var _sel = _vol + '-' + _page;
            var _pathVol;
            if (window.location.pathname.match('/volume/')
              && window.location.pathname.split('/').length > 2
              && !isNaN(parseInt(window.location.pathname.split('/')[2]))) {
              _pathVol = window.location.pathname.split('/')[2]
            }
            // document.querySelector('#2013-030-031') doesn't work if starting with a number :(
            if (document.querySelector("[id='" + _sel + "']") || _pathVol == _vol) {
              e.preventDefault();
              modalInstance.close();
              window.location.hash = _vol + '-' + _page;
            } else if (window.location.pathname.match('/volume/')) {
              e.preventDefault();
              modalInstance.close();
              window.location.href = '/volume/' + _vol + '#' + _vol + '-' + _page;
            }
          } catch (e) {
            //o noz! (~˘▾˘)~
          }
        }
      });
    },
    onCloseEnd: function (modal) {
      modal.querySelector('.tag-name').innerHTML = '';
      modal.querySelector('.collection').innerHTML = '';
    },
    preventScrolling: true
  });
}

var initProjectCitationModal = function () {
  document.querySelectorAll('.location-origin').forEach(function (el) {
    el.innerHTML = window.location.origin;
  });
  M.Modal.init(document.querySelectorAll('.modal:not(.tags)'));
}

var fetchProject = function (_this, setLocation) {
  var _project_href = _this.getAttribute('data-href');
  fetch(_project_href)
    .then(function (response) {
      return response.text();
    })
    .then(function (responseText) {
      const responseDOM = new DOMParser().parseFromString(responseText, 'text/html');
      _this.innerHTML = '';
      _this.appendChild(responseDOM.querySelector('article'));
      initTooltip();
      M.Materialbox.init(_this.querySelectorAll('.materialboxed'));
      initProjectTagModal();
      initProjectCitationModal();
    });
}

var loadProject = function (_this) {
  if (_this.previousElementSibling && _this.previousElementSibling.querySelector('.progress')) {
    // adding class here to prevent the size of the previous element from increasing and causing the current project to scroll down...
    _this.previousElementSibling.classList.add('clamp100vh');
    fetchProject(_this.previousElementSibling);
  }
  if (_this.querySelector('.progress')) {
    fetchProject(_this, true);
  }
  var nextProjElem = _this;
  for (var i = 0; i < 5; i++) {
    if (nextProjElem) {
      nextProjElem = nextProjElem.nextElementSibling;
      if (nextProjElem && nextProjElem.querySelector('.progress')) {
        fetchProject(nextProjElem);
      }
    }
  }
}

var scrollSpyEnter = function (navElemSelector, id) {
  var thisProject = document.querySelector("[id='" + id + "']")
  var indeterminateElem = thisProject.querySelector('.indeterminate')
  indeterminateElem && indeterminateElem.classList.remove('hidden');
  var scrollspyNavElem = document.querySelector('#scrollspy-nav');
  var navElem = scrollspyNavElem.querySelector(navElemSelector);
  thisProject.classList.remove('clamp100vh');
  if (navElem) {
    // navElem.classList.add('active');
    document.querySelector('#slide-out').scrollTo(window.scrollX, navElem.offsetTop - scrollspyNavElem.offsetTop)
  }
  loadProject(thisProject);
  if (window.history.pushState && window.location.hash !== '#' + id) {
    window.history.pushState(null, null, '#' + id);
  }
}

var debounceScrollSpyEnter = debounce(scrollSpyEnter, 100);


document.addEventListener('DOMContentLoaded', function () {

  document.querySelector('#slide-out').classList.remove('hidden');

  var getData = function () {
    fetch(BASE_URL + 'autocomplete.json', { headers: { "Accept": "application/json" } })
      .then(function (response) { return response.json() })
      .then(function (_data) {
        data = _data;
        if (window.localStorage) {
          window.localStorage.setItem("data", JSON.stringify(data));
        }
        initAutocomplete();
        setRandoProjectBanner();
      });
  }

  fetch(BASE_URL + 'autocomplete.json', { method: 'HEAD' })
    .then(function (response) {
      var currentTime;
      if (window.localStorage && window.localStorage.getItem("data-last-modified")) {
        currentTime = window.localStorage.getItem("data-last-modified");
      }
      var xhrTime = response.headers.get('Last-Modified');
      if (xhrTime != currentTime) {
        getData();
      }
      window.localStorage.setItem("data-last-modified", xhrTime)
    });

  if (!data) {
    if (window.localStorage && window.localStorage.getItem("data")) {
      data = JSON.parse(window.localStorage.getItem("data"));
      initAutocomplete();
      setRandoProjectBanner();
    } else {
      getData();
    }
  }

  var getTerms = function () {
    fetch(BASE_URL + 'index/terms.json', { headers: { "Accept": "application/json" } })
      .then(function (response) { return response.json() })
      .then(function (_terms) {
        terms = _terms;
        if (window.localStorage) {
          window.localStorage.setItem("terms", JSON.stringify(terms));
        }
      });
  }

  fetch(BASE_URL + 'index/terms.json', { method: 'HEAD' })
    .then(function (response) {
      var currentTime;
      if (window.localStorage && window.localStorage.getItem("terms-last-modified")) {
        currentTime = window.localStorage.getItem("terms-last-modified");
      }
      var xhrTime = response.headers.get('Last-Modified');
      if (xhrTime != currentTime) {
        getTerms();
      }
      window.localStorage.setItem("terms-last-modified", xhrTime)
    });

  if (!terms) {
    if (window.localStorage && window.localStorage.getItem("terms")) {
      terms = JSON.parse(window.localStorage.getItem("terms"));
    } else {
      getTerms();
    }
  }

  M.Sidenav.init(document.querySelectorAll('.sidenav'), {
    edge: 'right',
    draggable: true,
    onOpenEnd: function () {
      initTooltip();
    }
  });

  M.Collapsible.init(document.querySelectorAll('.collapsible-nav'));

  M.Collapsible.init(document.querySelectorAll('.indexes-collapsible'), {
    accordion: false,
    onOpenEnd: function (el) { setTimeout(function () { window.scrollTo(window.scrollX, el.offsetTop - 50) }, 100) }
  });

  M.Materialbox.init(document.querySelectorAll('.materialboxed'));

  initTooltip();

  initProjectTagModal();
  initProjectCitationModal();

  M.ScrollSpy.init(document.querySelectorAll('.scrollspy'), {
    scrollOffset: 0,
    getActiveElement: function (id) {
      var navElemSelector = 'a[href="#' + id + '"]';
      debounceScrollSpyEnter(navElemSelector, id);
      return navElemSelector;
    }
  });

  document.querySelectorAll('.project-load').forEach(function (el) {
    el.onclick = function () {
      loadProject(this.parentElement);
    }
  });

  if (window.location.hash.length) {
    var projectFromHash = document.querySelector("[id='" + window.location.hash.replace('#', '') + "']");
    projectFromHash && window.setTimeout(function () { window.scrollTo(window.scrollX, projectFromHash.offsetTop) }, 1000);
  } else if (/\/volume\//.test(window.location.pathname)) {
    // load the first project when the volume page loadz to avoid need a scroll event to trigger scrollSpy...
    var vol = window.location.pathname.split('/')[2];
    var introElem = document.querySelector("[id='" + vol + "-000-001']")
    vol && introElem && loadProject(introElem);
  }

  if(/\/index\/\d+/.test(window.location.pathname)){
    // if this is an index page; set tooltipz for project linkz w/ titlez.
    document.querySelectorAll('a[title]:not([title=""])').forEach(function (el) {
      el.classList.add('tooltipped');
      el.setAttribute('data-tooltip', el.getAttribute('title'));
    });
    if (document.querySelectorAll('a[title]:not([title=""])').length) {
      try {
        initTooltip();
      } catch (e) { /* eh... */ }
    }
  }
});
