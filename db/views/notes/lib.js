// Put functions specific to 'notes' here.
// Include in your views with
//
//   //include-lib

Util = {
  "dateAsArray": function(date_string) {
    date = new Date(date_string);
    return [date.getFullYear(), date.getMonth() + 1, date.getDay()];
  }
}
