let () =
  Lwt_main.run
    (let open Lwt_result.Syntax in
     let* db = Db.create () in
     let* () = Db.init db in
     let* () =
       Db.add
         db
         { author = "William Shakespeare"
         ; title = "Sonnet 18"
         ; text = "Shall I compare thee to a summer's day?"
         }
     in
     let* () =
       Db.add
         db
         { author = "William Shakespeare"
         ; title = "Sonnet 116"
         ; text = "Let me not to the marriage of true minds"
         }
     in
     let* results = Db.search db "Sonnet 18" in
     assert (List.length results = 1);
     assert ((List.hd results).title = "Sonnet 18");
     let* all = Db.search db "Shakespeare" in
     assert (List.length all = 2);
     Lwt.return_ok ())
  |> function
  | Ok () -> ()
  | Error err -> failwith (Caqti_error.show err)
;;
