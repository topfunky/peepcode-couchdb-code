function(doc) {
  if (doc.type == "Note" && doc.visited_on) {
    date_array = doc.visited_on.split("/");
    date_array = date_array.map(function(d) {
      return parseInt(d, 10);
    });
    emit(date_array, doc);
  }
}