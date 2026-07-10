let () =
  let db =
    Lwt_main.run
      (let open Lwt_result.Syntax in
       let* db = Db.create () in
       let* () = Db.init db in
       let* () = Db.populate db "poems.json" in
       Lwt.return_ok db)
    |> function
    | Ok db -> db
    | Error err -> failwith (Caqti_error.show err)
  in
  print_endline "Starting Publetry on http://0.0.0.0:8080";
  Web.run db
;;
