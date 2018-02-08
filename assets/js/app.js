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


$(function() {
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

  //nav
  $('.button-collapse').sideNav({
      // menuWidth: 300,
      edge: 'right',
      closeOnClick: true, 
      draggable: true
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


  $('.scrollspy').scrollSpy();

  var loadProject = function(_this){
    var _project_href = _this.attr('data-href');
    $('.material-tooltip').remove();
    _this.load(_project_href+' article');
    $('.tooltipped').tooltip();
    Materialize.fadeInImage('.project-img');
    setTimeout(function(){
      $('.materialboxed').materialbox();
    },500);
  }
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

  $('.project-load').click(function(){
    console.log('gonna load project via click!');
    loadProject($(this).parent());
  });
  
  var scrollSpyExit = function(){
    $('#scrollspy-nav').find('a[href="#' + $(this).attr('id') + '"]').removeClass('active');
  }

  $('.scrollspy').on('scrollSpy:enter', $.debounce(100, scrollSpyEnter) );
  $('.scrollspy').on('scrollSpy:exit', $.debounce(100, scrollSpyExit));


});
