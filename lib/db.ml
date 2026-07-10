type poem =
  { author : string
  ; title : string
  ; text : string
  }

type t = (Caqti_lwt.connection, Caqti_error.t) Caqti_lwt_unix.Pool.t

let uri = "sqlite3:./publetry.db"

let create () =
  match Caqti_lwt_unix.connect_pool (Uri.of_string uri) with
  | Ok pool -> Lwt.return_ok pool
  | Error err -> Lwt.return_error (err :> [> Caqti_error.t ])
;;

module Req = struct
  open Caqti_request.Infix
  open Caqti_type.Std

  let ddl = fun param qs -> (param ->. unit) ~oneshot:true qs

  let create_table =
    ddl
      unit
      "CREATE TABLE IF NOT EXISTS poems ( id INTEGER PRIMARY KEY AUTOINCREMENT, author \
       TEXT NOT NULL, title TEXT NOT NULL, text TEXT NOT NULL)"
  ;;

  let create_fts =
    ddl
      unit
      "CREATE VIRTUAL TABLE IF NOT EXISTS poems_fts USING fts5( author, title, \
       content='poems', content_rowid='id')"
  ;;

  let trigger_insert =
    ddl
      unit
      "CREATE TRIGGER IF NOT EXISTS poems_ai AFTER INSERT ON poems BEGIN INSERT INTO \
       poems_fts(rowid, author, title) VALUES (new.id, new.author, new.title); END"
  ;;

  let trigger_delete =
    ddl
      unit
      "CREATE TRIGGER IF NOT EXISTS poems_ad AFTER DELETE ON poems BEGIN INSERT INTO \
       poems_fts(poems_fts, rowid, author, title) VALUES ('delete', old.id, old.author, \
       old.title); END"
  ;;

  let trigger_update =
    ddl
      unit
      "CREATE TRIGGER IF NOT EXISTS poems_au AFTER UPDATE ON poems BEGIN INSERT INTO \
       poems_fts(poems_fts, rowid, author, title) VALUES ('delete', old.id, old.author, \
       old.title); INSERT INTO poems_fts(rowid, author, title) VALUES (new.id, \
       new.author, new.title); END"
  ;;

  let add =
    (t3 string string string ->. unit)
    @@ "INSERT INTO poems (author, title, text) VALUES (?, ?, ?)"
  ;;

  let search =
    (string ->* t3 string string string)
    @@ "SELECT p.author, p.title, p.text FROM poems_fts JOIN poems p ON p.id = \
        poems_fts.rowid WHERE poems_fts MATCH ? ORDER BY rank"
  ;;
end

let init pool =
  Caqti_lwt_unix.Pool.use
    (fun (module C : Caqti_lwt.CONNECTION) ->
       let open Lwt_result.Syntax in
       let* () = C.exec Req.create_table () in
       let* () = C.exec Req.create_fts () in
       let* () = C.exec Req.trigger_insert () in
       let* () = C.exec Req.trigger_delete () in
       C.exec Req.trigger_update ())
    pool
;;

let add pool { author; title; text } =
  Caqti_lwt_unix.Pool.use
    (fun (module C : Caqti_lwt.CONNECTION) -> C.exec Req.add (author, title, text))
    pool
;;

let search pool query =
  Caqti_lwt_unix.Pool.use
    (fun (module C : Caqti_lwt.CONNECTION) ->
       let open Lwt_result.Syntax in
       let* rows = C.collect_list Req.search query in
       Lwt.return_ok
         (List.map (fun (author, title, text) -> { author; title; text }) rows))
    pool
;;
