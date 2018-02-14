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


//#TODO: check if data has been updated, if so, re-init local storage
// var xhr = $.ajax( {
//   type: 'HEAD',
//   url: '/data.json',
//   success: function(msg) {
//       var filetime = xhr.getResponseHeader('Last-Modified');
//       console.log(filetime);
//   }
// });

$(function() {

  $('#slide-out').removeClass('hidden');
  $('#slide-out').isolatedScroll();
  
  var terms;
  $.getJSON('/index/terms.json', function(data){
    terms = data;
  });

  setTimeout(function(){
    $('.mat-select').material_select('destroy');
    $('.mat-select').material_select();
    try{
      // M.updateTextFields();
      Materialize.updateTextFields();
    }catch(e){
      //eh...
    }
  },600);

  //sidenav
  $('.button-collapse').sideNav({
      // menuWidth: 300,
      edge: 'right',
      closeOnClick: true, 
      draggable: true,
      onOpen: function(el) { 
        $('.material-tooltip').remove();
        $('.tooltipped').tooltip();
      }
    }
  );
  
  $('.collapsible-nav').collapsible({
    onOpen: function(el) { el.find('.indicator').animateRotate(180); },
    onClose: function(el) { el.find('.indicator').animateRotate(0); }
  });


  //volumes
  $('.indexes-collapsible').collapsible({
    onOpen: function(el) { setTimeout(function(){window.scrollTo(window.scrollX, el.position().top - 50)}, 250) }
  });

  $('.materialboxed').materialbox();

  // $('#projects-table tbody tr td').unbind('click');
  // $('#projects-table tbody tr td').click(function () {
  //   location.href = $(this).parent().data('project-href');
  // });
  // $('#projects-table tbody tr td.has-action').unbind('click');


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
            if($(_sel).length){
              e.preventDefault();
              modal.modal('close');
              // window.scrollTo(window.scrollX, $(_sel).position().top);
              location.hash = _vol+'-'+_page;
              //$('body').removeAttr('style'); //aarg. #hamfist ...how is overflow:hidden getting here right now?
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
