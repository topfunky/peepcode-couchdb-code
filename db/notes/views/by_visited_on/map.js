// !code lib/lib.js
function(doc) {
  if (doc.type == "Note" && doc.visited_on) {
    emit(Util.dateAsArray(doc.visited_on), doc);
  }
}