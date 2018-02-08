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

});
