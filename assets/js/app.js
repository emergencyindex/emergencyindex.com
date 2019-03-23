var BASE_URL = "/";
var data, terms;


var initAutocomplete = function(){
  var dataObj = {};
  var hrefObj = {};

  for(var proj of data){
    if(proj.title != ''){
      var _key = proj.title + ' -- ' + proj.contributor + ' -- ' + proj.place;
      dataObj[_key] = null; //'/assets/img/'+proj.volume+'/'+proj.image;
      hrefObj[_key+'HREF'] = proj.url;
    }
  }

  M.Autocomplete.init(document.querySelectorAll('input.autocomplete'), {
    data: dataObj,
    limit: 50,
    onAutocomplete: function(val) {
      var projKey = Object.keys(hrefObj).filter(function(i){return i.match(val)})[0]
      if(projKey && hrefObj[projKey]){
        window.location = hrefObj[projKey]; //+'/?s='+val;
      }
    },
    minLength: 1
  });
}

// var setRandoProjectBannerInterval;

var setRandoProjectBanner = function() {
  // if(!setRandoProjectBannerInterval){
  //   setRandoProjectBannerInterval = window.setInterval(setRandoProjectBanner, 5000);
  // }
  var projectBannerLink = document.querySelector('.project-banner-link');
  if(projectBannerLink){
      var randoProject = data[ Math.floor(Math.random() * data.length - 1) ];
      // console.log('randoProject:',randoProject)
      // projectBannerLink.href = randoProject.url;
      var _href = randoProject.url.split('/');
      var _page = _href.pop();
      var _vol  = _href.pop();
      projectBannerLink.href = '/volume/'+_vol+'#'+_vol+'-'+_page;
      projectBannerLink.title = randoProject.title + ' -- ' + randoProject.contributor;

      var projectBannerElem = document.querySelector('.project-banner-elem');
      projectBannerElem.style.backgroundImage = 'url("/assets/img/'+randoProject.volume+'/'+randoProject.image+'")';
      window.setTimeout(function(){projectBannerElem.classList.add('project-banner-elem-anim');}, 10);
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

var initTooltip = function() {
  var tooltipElemz = document.querySelectorAll('.tooltipped');
  tooltipElemz.forEach(function(el){
    try{
      M.Tooltip.getInstance(el).destroy()
    }catch(e) { /* ...eh */ }
  })
  M.Tooltip.init(tooltipElemz);
}

var initProjectTagModal = function(){
  var modalz = document.querySelectorAll('.modal');
  
  M.Modal.init(modalz, {
    onOpenStart: function(modal, trigger) {
      var tag = trigger.getAttribute('data-tag');
      modal.querySelector('.tag-name').innerHTML = tag;
      if(terms[tag]){
        var caption = terms[tag].length + " project" + (terms[tag].length != 1 ? "s" : "");
        var badge = document.createElement("span"); 
        badge.classList.add('badge');
        badge.setAttribute('data-badge-caption', caption);
        modal.querySelector('.tag-name').appendChild(badge);

        var items = [];
        for(var t of terms[tag]){
          items.push( "<a href='"+t.url+"' class='collection-item project-tag'  >"+t.title+" -- "+t.contributor+" <span class='badge'>"+t.volume+"</span></>" );
        }
        modal.querySelector('.collection').innerHTML = items.join('');
      }
      modal.querySelectorAll('.project-tag').forEach( function(el){
        el.onclick = function(e){
          var modalInstance = M.Modal.getInstance(modal);
          try{
            var _href = this.getAttribute('href').split('/');
            var _page = _href.pop();
            var _vol  = _href.pop();
            var _sel  = _vol+'-'+_page;
            var _pathVol;
            if(  window.location.pathname.match('/volume/')
              && window.location.pathname.split('/').length > 2
              && !isNaN(parseInt(window.location.pathname.split('/')[2])) ){
              _pathVol = window.location.pathname.split('/')[2]
            }
            // document.querySelector('#2013-030-031') doesn't work if starting with a number :(
            if(document.querySelector("[id='"+_sel+"']") || _pathVol == _vol){
              e.preventDefault();
              modalInstance.close();
              window.location.hash = _vol+'-'+_page;
            }else if(window.location.pathname.match('/volume/')){
              e.preventDefault();
              modalInstance.close();
              window.location.href = '/volume/'+_vol+'#'+_vol+'-'+_page;
            }
          }catch(e){
            //o noz! (~˘▾˘)~
          }
        }
      });
    },
    onCloseEnd: function(modal) {
      modal.querySelector('.tag-name').innerHTML = '';
      modal.querySelector('.collection').innerHTML = '';
    },
    preventScrolling: true
  });
}

var loadProject = function(_this){
  var _project_href = _this.getAttribute('data-href');
  fetch(_project_href)
  .then(function(response) {
    return response.text();
  })
  .then(function(responseText){
    const responseDOM = new DOMParser().parseFromString(responseText, 'text/html');
    _this.innerHTML = '';
    _this.appendChild(responseDOM.querySelector('article'));

    // $('.tooltipped').tooltip();
    initTooltip();
    M.Materialbox.init(_this.querySelectorAll('.materialboxed'));
    // M.fadeInImage(_this.find('.project-img'));
    initProjectTagModal();
    var _project_href = _this.getAttribute('data-href').split('/');
    if(_project_href.length){
      var _page = _project_href.pop();
      var _vol  = _project_href.pop();
      location.hash = _vol+'-'+_page;
    }
  });
}


document.addEventListener('DOMContentLoaded', function() {
  // M.AutoInit(); 
  document.querySelector('#slide-out').classList.remove('hidden');
  // document.querySelector('#slide-out').bind('mousewheel DOMMouseScroll', function (e) {
  //   var delta = e.wheelDelta || (e.originalEvent && e.originalEvent.wheelDelta) || -e.detail,
  //     bottomOverflow = this.scrollTop + this.clientHeight - this.scrollHeight >= 0,
  //     topOverflow = this.scrollTop <= 0;
  //   if ((delta < 0 && bottomOverflow) || (delta > 0 && topOverflow)) {
  //     e.preventDefault();
  //   }
  // });

  var getData = function(){
    fetch(BASE_URL+'autocomplete.json', {headers: {"Accept": "application/json"}})
    .then(function(response){return response.json()})
    .then(function(_data){
      data = _data;
      if(window.localStorage){
        window.localStorage.setItem("data", JSON.stringify(data));
      }
      initAutocomplete();
      setRandoProjectBanner();
    });
  }

  fetch(BASE_URL+'autocomplete.json', {method: 'HEAD'})
  .then(function(response){
    var currentTime;
    if(window.localStorage && window.localStorage.getItem("data-last-modified")){
      currentTime = window.localStorage.getItem("data-last-modified");
    }
    var xhrTime = response.headers.get('Last-Modified');
    if( xhrTime != currentTime ){
      getData();
    }
    window.localStorage.setItem("data-last-modified", xhrTime )
  });

  if(!data){
    if(window.localStorage && window.localStorage.getItem("data")){
      data = JSON.parse(window.localStorage.getItem("data"));
      initAutocomplete();
      setRandoProjectBanner();
    }else{
      getData();
    }
  }

  var getTerms = function(){
    fetch(BASE_URL+'index/terms.json', {headers: {"Accept": "application/json"}})
    .then(function(response){return response.json()})
    .then(function(_terms){
      terms = _terms;
      if(window.localStorage){
        window.localStorage.setItem("terms", JSON.stringify(terms));
      }
    });
  }

  fetch(BASE_URL+'index/terms.json', {method: 'HEAD'})
  .then(function(response){
    var currentTime;
    if(window.localStorage && window.localStorage.getItem("terms-last-modified")){
      currentTime = window.localStorage.getItem("terms-last-modified");
    }
    var xhrTime = response.headers.get('Last-Modified');
    if( xhrTime != currentTime ){
      getTerms();
    }
    window.localStorage.setItem("terms-last-modified", xhrTime )
  });

  if(!terms){
    if(window.localStorage && window.localStorage.getItem("terms")){
      terms = JSON.parse(window.localStorage.getItem("terms"));
    }else{
      getTerms();
    }
  }

  //sidenav
  M.Sidenav.init(document.querySelectorAll('.sidenav'), {
    edge: 'right',
    draggable: true,
  });

  M.Collapsible.init(document.querySelectorAll('.collapsible-nav'));

  M.Collapsible.init(document.querySelectorAll('.indexes-collapsible'), {
    accordion: false,
    onOpenEnd: function(el) { setTimeout(function(){window.scrollTo(window.scrollX, el.offsetTop - 50)}, 100) }
  });

  M.Materialbox.init(document.querySelectorAll('.materialboxed'));

  initTooltip();

  initProjectTagModal();

  M.ScrollSpy.init(document.querySelectorAll('.scrollspy'));

  // var scrollSpyEnter = function() {
  //   console.log('scrollSpyEnter!')
  //   var indeterminateElem = this.querySelector('.indeterminate')
  //   indeterminateElem && indeterminateElem.classList.remove('hidden');
  //   // var $navElem = $('#scrollspy-nav').find('a[href="#' + $(this).attr('id') + '"]');
  //   var scrollspyNavElem = document.querySelector('#scrollspy-nav');
  //   var navElem = scrollspyNavElem.querySelector('a[href="#' + this.id + '"]')

  //   if(navElem){
  //     navElem.classList.add('active');
  //     document.querySelector('#slide-out').scrollTo(0, navElem.offsetTop - scrollspyNavElem.offsetTop)
  //   }

  //   // for(i=0;i < $('.collapsible-nav-item').length; i++){
  //   //   $('.collapsible-nav').collapsible('close',i);
  //   // }

  //   if(this.querySelector('.progress')){
  //     loadProject(this);
  //   }

  // }

  // var scrollSpyExit = function(){
  //   // $('#scrollspy-nav').find('a[href="#' + $(this).attr('id') + '"]').removeClass('active');
  //   var scrollspyNavElem = document.querySelector('#scrollspy-nav');
  //   var navElem = scrollspyNavElem.querySelector('a[href="#' + this.id + '"]')
  //   if(navElem){
  //     navElem.classList.remove('active')
  //   }
  // }

  // document.querySelectorAll('.scrollspy').forEach(function(el){
  //   // el.addEventListener('scrollSpy:enter', $.debounce(100, scrollSpyEnter));
  //   // el.addEventListener('scrollSpy:exit', $.debounce(50, scrollSpyExit));

  //   var instance = M.ScrollSpy.getInstance(el);
  //   console.log('scrollspy instance:', instance)
  //   el.addEventListener('scrollSpy:enter', scrollSpyEnter);
  //   el.addEventListener('scrollSpy:exit', scrollSpyExit);
  // })
  // // $('.scrollspy').on('scrollSpy:enter', $.debounce(100, scrollSpyEnter) );
  // // $('.scrollspy').on('scrollSpy:exit', $.debounce(50, scrollSpyExit));

  document.querySelectorAll('.project-load').forEach(function(el){
    el.onclick = function(){
      loadProject(this.parentElement);
    }
  });

  var projectFromHash = document.querySelector("[id='"+window.location.hash.replace('#','')+"']");
  if(window.location.hash.length && projectFromHash){
    window.scrollTo(window.scrollX, projectFromHash.offsetTop);
  }

});


