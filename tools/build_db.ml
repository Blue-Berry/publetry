let () =
  if Array.length Sys.argv <> 3
  then (
    Printf.eprintf "usage: %s <output.db> <poems.json>\n" Sys.argv.(0);
    exit 1);
  let db_path = Sys.argv.(1) in
  let poems_path = Sys.argv.(2) in
  Lwt_main.run
    (let open Lwt_result.Syntax in
     let* db = Db.connect ("sqlite3:" ^ db_path) in
     let* () = Db.init db in
     let* () = Db.populate db poems_path in
     let* () = Lwt_result.ok (Db.close db) in
     Lwt.return_ok ())
  |> function
  | Ok () -> ()
  | Error err -> failwith (Caqti_error.show err)
;;
