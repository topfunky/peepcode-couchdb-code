// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

Event.addBehavior({
  "#note_title:keyup": function(e) {
    if ($F(this).blank()) {
      $('title').innerHTML = "Note";
    } else {
      $('title').innerHTML = $F(this);
    }
  },
  "#date": DateSelector,
});
