var BASE_URL = "/";
var data, terms;

$.fn.animateRotate = function(angle, duration, easing, complete) {
  var args = $.speed(duration, easing, complete);
  var step = args.step;
  return this.each(function(i, e) {
    args.complete = $.proxy(args.complete, e);
    args.step = function(now) {
      $.style(e, 'transform', 'rotate(' + now + 'deg)');
      if (step) return step.apply(e, arguments);
    };

    $({deg: 0}).animate({deg: angle}, args);
  });
};

$.fn.isolatedScroll = function() {
  this.bind('mousewheel DOMMouseScroll', function (e) {
    var delta = e.wheelDelta || (e.originalEvent && e.originalEvent.wheelDelta) || -e.detail,
      bottomOverflow = this.scrollTop + $(this).outerHeight() - this.scrollHeight >= 0,
      topOverflow = this.scrollTop <= 0;
    if ((delta < 0 && bottomOverflow) || (delta > 0 && topOverflow)) {
      e.preventDefault();
    }
  });
  return this;
};


$(function() {

  M.AutoInit(); 

  $('#slide-out').removeClass('hidden');
  $('#slide-out').isolatedScroll();

  var initAutocomplete = function(){

    var dataObj = {};
    var hrefObj = {};

    if($('.tag-slug').length > 0){
      $("label[for='autocomplete-input']").html('Search Terms')
      $('.tag-slug').each(function(tag){
        var _key = $(this).html();
        dataObj[_key] = null;
        hrefObj[_key+'HREF'] = '#'+$(this).attr('id');
      })
    }else{
       _.each(data, function(proj){
        if(proj.title != ''){

          var _key = proj.title + ' -- ' + proj.contributor + ' -- ' + proj.place;
          dataObj[_key] = null; //'/assets/img/'+proj.volume+'/'+proj.image;
          hrefObj[_key+'HREF'] = proj.url;
        }
      });
    }

    // console.log('gonna init autocomplete...')
    $('input.autocomplete').autocomplete({
      data: dataObj,
      limit: 50,
      onAutocomplete: function(val) {
        if(hrefObj[val+'HREF']){
          window.location = hrefObj[val+'HREF']; //+'/?s='+val;
          if($('.tag-slug').length > 0){
            window.scrollTo(window.scrollX, $(window.location.hash).position().top - 50);
          }

        }
      },
      minLength: 1
    });


    // if(location.search.split('s=')[1]){
    //   $('input.autocomplete').val(decodeURI(location.search.split('s=')[1]));
    // }
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

  var getData = function(){
    $.ajax({
      type: 'GET',
      url: BASE_URL+'autocomplete.json',
      dataType: 'json',
      success: function(j, xhr){
        data = j;
        if(window.localStorage){
          window.localStorage.setItem("data", JSON.stringify(data));
        }
        initAutocomplete();
        setRandoProjectBanner();
      }
    });
  }

  var dataXHR = $.ajax( {
    type: 'HEAD',
    url: BASE_URL+'autocomplete.json',
    success: function() {
      var currentTime;
      if(window.localStorage && window.localStorage.getItem("data-last-modified")){
        currentTime = window.localStorage.getItem("data-last-modified");
      }
      var xhrTime = dataXHR.getResponseHeader('Last-Modified');
      if( xhrTime != currentTime ){
        getData();
      }
      window.localStorage.setItem("data-last-modified", xhrTime )
    }
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
    $.ajax({
      type: 'GET',
      url: BASE_URL+'index/terms.json',
      dataType: 'json',
      success: function(j, xhr){
        terms = j;
        if(window.localStorage){
          window.localStorage.setItem("terms", JSON.stringify(terms));
        }
      }
    });
  }

  var termsXHR = $.ajax( {
    type: 'HEAD',
    url: BASE_URL+'index/terms.json',
    success: function() {
      var currentTime;
      if(window.localStorage && window.localStorage.getItem("terms-last-modified")){
        currentTime = window.localStorage.getItem("terms-last-modified");
      }
      var xhrTime = termsXHR.getResponseHeader('Last-Modified');
      if( xhrTime != currentTime ){
        getTerms();
      }
      window.localStorage.setItem("terms-last-modified", xhrTime )
    }
  });


  if(!terms){
    if(window.localStorage && window.localStorage.getItem("terms")){
      terms = JSON.parse(window.localStorage.getItem("terms"));
    }else{
      getTerms();
    }
  }


  setTimeout(function(){
    $('.mat-select').formSelect('destroy');
    $('.mat-select').formSelect();
    try{
      // M.updateTextFields();
      Materialize.updateTextFields();
    }catch(e){
      //eh...
    }
  },600);

  //sidenav
  $('.sidenav').sidenav({
      // menuWidth: 300,
      edge: 'right',
      // closeOnClick: true,
      draggable: true,
      onOpenEnd: function(el) {
        $('.material-tooltip').remove();
        $('.tooltipped').tooltip();
      }
    }
  );

  $('.collapsible-nav').collapsible({
    onOpenEnd: function(el) { el.find('.indicator').animateRotate(180); },
    onCloseEnd: function(el) { el.find('.indicator').animateRotate(0); }
  });

  $('.indexes-collapsible').collapsible({
    accordion: false,
    onOpenEnd: function(el) { setTimeout(function(){window.scrollTo(window.scrollX, el.position().top - 50)}, 100) }
  });

  $('.materialboxed').materialbox();

  var initProjectTagModal = function(){
    $('.modal').modal({
      ready: function(modal, trigger) {
        var tag = trigger.attr('data-tag');
        modal.find('.tag-name').html(tag);
        if(terms[tag]){
          var caption = terms[tag].length + " project" + (terms[tag].length != 1 ? "s" : "");
          $("<span/>", {
            "class": "badge",
            "data-badge-caption": caption
          }).appendTo(modal.find('.tag-name'));

          var items = [];
          $.each( terms[tag], function(key, t) {
            items.push( "<a href='"+t.url+"' class='collection-item project-tag'  >"+t.title+" -- "+t.contributor+" <span class='badge'>"+t.volume+"</span></>" );
          });
          modal.find('.collection').html(items.join(''));
        }
        $('.material-tooltip').remove();
        $('.tooltipped').tooltip();
        modal.find('.project-tag').click(function(e){
          try{
            var _href = $(this).attr('href').split('/');
            var _page = _href.pop();
            var _vol  = _href.pop();
            var _sel  ='#'+_vol+'-'+_page;

            var _pathVol;
            if(  window.location.pathname.match('/volume/')
              && window.location.pathname.split('/').length > 2
              && !isNaN(parseInt(window.location.pathname.split('/')[2])) ){
              _pathVol = window.location.pathname.split('/')[2]
            }
            if($(_sel).length || _pathVol == _vol){
              e.preventDefault();
              modal.modal('close');
              location.hash = _vol+'-'+_page;
            }else if(window.location.pathname.match('/volume/')){
              e.preventDefault();
              modal.modal('close');
              location.href = '/volume/'+_vol+'#'+_vol+'-'+_page;
            }
          }catch(e){
            //o noz! (~˘▾˘)~
          }
        });
      },
      complete: function(modal) {
        modal.find('.tag-name').html('');
        modal.find('.collection').html('');
      }
    });
  }

  initProjectTagModal();

  var loadProject = function(_this){
    var _project_href = _this.attr('data-href');
    $('.material-tooltip').remove();
    _this.load(_project_href+' article', function(){
      $('.tooltipped').tooltip();
      _this.find('.materialboxed').materialbox();
      Materialize.fadeInImage(_this.find('.project-img'));
      initProjectTagModal();
      var _project_href = $(this).attr('data-href').split('/');
      if(_project_href.length){
        var _page = _project_href.pop();
        var _vol  = _project_href.pop();
        location.hash = _vol+'-'+_page;
      }
    });
  }

  $('.scrollspy').scrollSpy();

  var scrollSpyEnter = function() {
    $(this).find('.indeterminate').removeClass('hidden');
    var $navElem = $('#scrollspy-nav').find('a[href="#' + $(this).attr('id') + '"]');
    if( $navElem.length ){
      $navElem.addClass('active');
      $('#slide-out').animate({
          scrollTop: $navElem.offset().top - $('#scrollspy-nav').offset().top
      }, 100);
    }

    for(i=0;i < $('.collapsible-nav-item').length; i++){
      $('.collapsible-nav').collapsible('close',i);
    }

    if($(this).find('.progress').length){
      loadProject($(this));
    }

  }

  var scrollSpyExit = function(){
    $('#scrollspy-nav').find('a[href="#' + $(this).attr('id') + '"]').removeClass('active');
  }

  $('.scrollspy').on('scrollSpy:enter', $.debounce(100, scrollSpyEnter) );
  $('.scrollspy').on('scrollSpy:exit', $.debounce(50, scrollSpyExit));

  $('.project-load').click(function(){
    loadProject($(this).parent());
  });

  if(window.location.hash.length && $(window.location.hash).length){
    window.scrollTo(window.scrollX, $(window.location.hash).position().top);
  }

});
