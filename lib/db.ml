type poem =
  { author : string
  ; title : string
  ; text : string
  }

type t = (Caqti_lwt.connection, Caqti_error.t) Caqti_lwt_unix.Pool.t

let uri = "sqlite3:./publetry.db"

let connect uri_string =
  match Caqti_lwt_unix.connect_pool (Uri.of_string uri_string) with
  | Ok pool -> Lwt.return_ok pool
  | Error err -> Lwt.return_error (err :> [> Caqti_error.t ])
;;

let create () = connect uri
let close pool = Caqti_lwt_unix.Pool.drain pool

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

  let search_authors =
    (string ->* string)
    @@ "SELECT p.author FROM poems_fts JOIN poems p ON p.id = poems_fts.rowid WHERE \
        poems_fts MATCH ? ORDER BY rank"
  ;;

  let search_titles =
    (string ->* string)
    @@ "SELECT p.title FROM poems_fts JOIN poems p ON p.id = poems_fts.rowid WHERE \
        poems_fts MATCH ? ORDER BY rank"
  ;;

  let find =
    (t2 string string ->? t3 string string string)
    @@ "SELECT author, title, text FROM poems WHERE author = ? COLLATE NOCASE AND title \
        = ? COLLATE NOCASE LIMIT 1"
  ;;

  let find_by_author =
    (string ->* t3 string string string)
    @@ "SELECT author, title, text FROM poems WHERE author = ? COLLATE NOCASE ORDER BY \
        title"
  ;;

  let count = (unit ->! int) @@ "SELECT COUNT(*) FROM poems"
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

let quote_token tok =
  let escaped = String.concat "\"\"" (String.split_on_char '"' tok) in
  "\"" ^ escaped ^ "\""
;;

let tokens raw =
  let trimmed = String.trim raw in
  if String.length trimmed = 0
  then []
  else
    trimmed
    |> String.map (function
      | '\t' | '\n' | '\r' -> ' '
      | c -> c)
    |> String.split_on_char ' '
    |> List.filter (fun s -> String.length s > 0)
;;

let fts5_query ?(prefix = "") raw =
  tokens raw |> List.map (fun tok -> prefix ^ quote_token tok) |> String.concat " AND "
;;

let run_search pool query =
  if String.length query = 0
  then Lwt.return_ok []
  else
    Caqti_lwt_unix.Pool.use
      (fun (module C : Caqti_lwt.CONNECTION) ->
         let open Lwt_result.Syntax in
         let* rows = C.collect_list Req.search query in
         Lwt.return_ok
           (List.map (fun (author, title, text) -> { author; title; text }) rows))
      pool
;;

let search pool raw_query = run_search pool (fts5_query raw_query)

let search_authors pool raw_query =
  let query = fts5_query ~prefix:"author:" raw_query in
  if String.length query = 0
  then Lwt.return_ok []
  else
    Caqti_lwt_unix.Pool.use
      (fun (module C : Caqti_lwt.CONNECTION) ->
         let open Lwt_result.Syntax in
         let* authors = C.collect_list Req.search_authors query in
         Lwt.return_ok (List.sort_uniq String.compare authors))
      pool
;;

let search_author pool raw_author =
  run_search pool (fts5_query ~prefix:"author:" raw_author)
;;

let search_title ?author pool raw_title =
  let author_clauses =
    match author with
    | None -> []
    | Some a ->
      let trimmed = String.trim a in
      if String.length trimmed = 0 then [] else [ "author:" ^ quote_token trimmed ]
  in
  let title_clauses =
    tokens raw_title |> List.map (fun tok -> "title:" ^ quote_token tok)
  in
  let clauses = author_clauses @ title_clauses in
  run_search pool (String.concat " AND " clauses)
;;

let search_titles pool raw_query =
  let query = fts5_query ~prefix:"title:" raw_query in
  if String.length query = 0
  then Lwt.return_ok []
  else
    Caqti_lwt_unix.Pool.use
      (fun (module C : Caqti_lwt.CONNECTION) ->
         let open Lwt_result.Syntax in
         let* titles = C.collect_list Req.search_titles query in
         Lwt.return_ok (List.sort_uniq String.compare titles))
      pool
;;

let find pool ~author ~title =
  Caqti_lwt_unix.Pool.use
    (fun (module C : Caqti_lwt.CONNECTION) ->
       let open Lwt_result.Syntax in
       let* row = C.find_opt Req.find (author, title) in
       Lwt.return_ok
         (Option.map (fun (author, title, text) -> { author; title; text }) row))
    pool
;;

let find_by_author pool author =
  Caqti_lwt_unix.Pool.use
    (fun (module C : Caqti_lwt.CONNECTION) ->
       let open Lwt_result.Syntax in
       let* rows = C.collect_list Req.find_by_author author in
       Lwt.return_ok
         (List.map (fun (author, title, text) -> { author; title; text }) rows))
    pool
;;

let count pool =
  Caqti_lwt_unix.Pool.use
    (fun (module C : Caqti_lwt.CONNECTION) -> C.find Req.count ())
    pool
;;

let error_of_path path msg =
  Caqti_error.request_failed ~uri:(Uri.of_string uri) ~query:path (Caqti_error.Msg msg)
;;

let json_to_poem json =
  let open Yojson.Safe.Util in
  { author = json |> member "Author" |> to_string
  ; title = json |> member "Title" |> to_string
  ; text = json |> member "text" |> to_string
  }
;;

let parse_poems path contents =
  try
    Ok
      (Yojson.Safe.from_string contents
       |> Yojson.Safe.Util.to_list
       |> List.map json_to_poem)
  with
  | exn -> Error (error_of_path path (Printexc.to_string exn))
;;

let populate pool path =
  let open Lwt_result.Syntax in
  let* contents =
    Lwt.catch
      (fun () ->
         Lwt.map Result.ok Lwt_io.(with_file ~mode:input path (fun ch -> read ch)))
      (fun exn -> Lwt.return_error (error_of_path path (Printexc.to_string exn)))
  in
  let* poems = Lwt.return (parse_poems path contents) in
  Caqti_lwt_unix.Pool.use
    (fun (module C : Caqti_lwt.CONNECTION) ->
       C.with_transaction (fun () ->
         let rec loop = function
           | [] -> Lwt.return_ok ()
           | { author; title; text } :: rest ->
             let* () = C.exec Req.add (author, title, text) in
             loop rest
         in
         loop poems))
    pool
;;
