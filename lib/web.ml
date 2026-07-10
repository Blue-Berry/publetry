let json_strings strings =
  `List (List.map (fun s -> `String s) strings) |> Yojson.Safe.to_string
;;

let index _request =
  Dream.html
    {|<h1>Publetry</h1>
<ul>
  <li><code>GET /authors?q=...</code> &mdash; search authors</li>
  <li><code>GET /titles?q=...&amp;author=...</code> &mdash; search poem titles (author optional)</li>
  <li><code>GET /poems?author=...</code> &mdash; list all poems by an author</li>
  <li><code>GET /epub?author=...&amp;title=...</code> &mdash; download a poem as EPUB3</li>
</ul>|}
;;

let authors db request =
  let open Lwt.Syntax in
  match Dream.query request "q" with
  | None -> Dream.empty `Bad_Request
  | Some q ->
    let* result = Db.search_authors db q in
    (match result with
     | Ok authors -> Dream.json (json_strings authors)
     | Error err -> Dream.respond ~status:`Internal_Server_Error (Caqti_error.show err))
;;

let json_title Db.{ author; title; _ } =
  `Assoc [ "author", `String author; "title", `String title ]
;;

let titles db request =
  let open Lwt.Syntax in
  match Dream.query request "q" with
  | None -> Dream.empty `Bad_Request
  | Some q ->
    let author = Dream.query request "author" in
    let* result = Db.search_title db ?author q in
    (match result with
     | Ok poems -> Dream.json (`List (List.map json_title poems) |> Yojson.Safe.to_string)
     | Error err -> Dream.respond ~status:`Internal_Server_Error (Caqti_error.show err))
;;

let json_poem Db.{ author; title; text } =
  `Assoc [ "author", `String author; "title", `String title; "text", `String text ]
;;

let poems db request =
  let open Lwt.Syntax in
  match Dream.query request "author" with
  | None -> Dream.empty `Bad_Request
  | Some author ->
    let* result = Db.find_by_author db author in
    (match result with
     | Ok poems -> Dream.json (`List (List.map json_poem poems) |> Yojson.Safe.to_string)
     | Error err -> Dream.respond ~status:`Internal_Server_Error (Caqti_error.show err))
;;

let epub db request =
  let open Lwt.Syntax in
  match Dream.query request "author", Dream.query request "title" with
  | Some author, Some title ->
    let* result = Db.search_title db ~author title in
    (match result with
     | Ok (poem :: _) ->
       let* epub_result = Epub.generate poem in
       (match epub_result with
        | Ok bytes ->
          Dream.respond ~headers:[ "Content-Type", "application/epub+zip" ] bytes
        | Error msg -> Dream.respond ~status:`Internal_Server_Error msg)
     | Ok [] -> Dream.empty `Not_Found
     | Error err -> Dream.respond ~status:`Internal_Server_Error (Caqti_error.show err))
  | _ -> Dream.empty `Bad_Request
;;

let router db =
  Dream.router
    [ Dream.get "/" index
    ; Dream.get "/authors" (authors db)
    ; Dream.get "/titles" (titles db)
    ; Dream.get "/poems" (poems db)
    ; Dream.get "/epub" (epub db)
    ]
;;

let run db = Dream.run ~interface:"0.0.0.0" ~port:8080 (router db)
