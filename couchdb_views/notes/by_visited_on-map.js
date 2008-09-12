function(doc) {
  if (doc.type == "Note" && doc.visited_on) {
    emit(doc.visited_on, doc);
  }
}