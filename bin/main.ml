let () =
  Lwt_main.run
    (let open Lwt_result.Syntax in
     let* db = Db.create () in
     let* () = Db.init db in
     let* () = Db.populate db "poems.json" in
     let* results = Db.search db "Robert Herrick" in
     List.iter
       (fun Db.{ author; title; _ } -> Printf.printf "%s — %s\n" author title)
       results;
     Lwt.return_ok ())
  |> function
  | Ok () -> ()
  | Error err -> failwith (Caqti_error.show err)
;;
