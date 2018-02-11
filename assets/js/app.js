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

  var terms;
  $.getJSON('/index/terms.json', function(data){
    terms = data;
  })

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
    onOpen: function(el) { setTimeout(function(){el[0].scrollIntoView()}, 250) }
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
            items.push( "<a href='"+t.url+"' class='collection-item'>"+t.title+" -- "+t.contributor+" <span class='badge'>"+t.volume+"</span></>" );
          });
          modal.find('.collection').html(items.join(''));
        }
        $('.material-tooltip').remove();
        $('.tooltipped').tooltip();
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
    _this.load(_project_href+' article');
    $('.tooltipped').tooltip();
    Materialize.fadeInImage('.project-img');
    setTimeout(function(){
      $('.materialboxed').materialbox();
      initProjectTagModal();
    }, 100);
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

});
