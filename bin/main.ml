let usage () =
  Printf.eprintf "usage: %s <db-path>\n" Sys.argv.(0);
  exit 1
;;

let () =
  if Array.length Sys.argv < 2 then usage ();
  let db_path = Sys.argv.(1) in
  let uri =
    if String.starts_with ~prefix:"sqlite3:" db_path
    then db_path
    else "sqlite3:" ^ db_path
  in
  let db =
    Lwt_main.run
      (let open Lwt_result.Syntax in
       let* db = Db.connect uri in
       let* () = Db.init db in
       let* n = Db.count db in
       let* () = if n = 0 then Db.populate db "poems.json" else Lwt.return_ok () in
       Lwt.return_ok db)
    |> function
    | Ok db -> db
    | Error err -> failwith (Caqti_error.show err)
  in
  Printf.printf "Starting Publetry on http://0.0.0.0:8080 (db: %s)\n%!" uri;
  Web.run db
;;
