function(doc) {
  if (doc.type == "Note") {
    emit(doc.title, doc);
  }
}