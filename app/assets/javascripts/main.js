$(document).ready(function(){
  pageInit();
});

$(window).bind('page:change', function() {
  pageInit();
})

function pageInit() {
  $.each($('textarea'), function(index, el){
    $(el).wysihtml5({
      "font-styles": true, //Font styling, e.g. h1, h2, etc. Default true
      "emphasis": true, //Italics, bold, etc. Default true
      "lists": true, //(Un)ordered lists, e.g. Bullets, Numbers. Default true
      "html": false, //Button which allows you to edit the generated HTML. Default false
      "link": true, //Button to insert a link. Default true
      "image": false, //Button to insert an image. Default true,
      "color": false //Button to change color of font
    });
  });

  // NEW SIT / title or duration
  $('.new-sit .radio_buttons input').click( function() {
    if ($(this).attr('id') == 'sit_s_type_0') {
      // Show the duration if 'sit' is selected
      $('.new-sit-title').hide();
      $('.new-sit-duration').fadeIn();
    } else {
      $('.new-sit-duration').hide();
      $('.new-sit-title').fadeIn();
    }
  });

  // NEW SIT / datepicker
  $('.new-sit #datepicker').datepicker({
    format: 'yyyy-mm-dd',
    autoclose: true,
    language: 'en',
  });

  $(".chzn-select").chosen();
}