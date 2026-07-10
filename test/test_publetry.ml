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
     let* () = Db.populate db "poems.json" in
     let* herrick = Db.search db "Robert Herrick" in
     assert (List.length herrick > 0);
     let* herrick_author = Db.search_author db "Robert Herrick" in
     assert (List.length herrick_author > 0);
     let* harvest = Db.search_title db "Harvest Home" in
     assert (List.length harvest > 0);
     let* filtered = Db.search_title db ~author:"Robert Herrick" "Harvest" in
     assert (List.length filtered > 0);
     assert (List.for_all (fun Db.{ author; _ } -> author = "Robert Herrick") filtered);
     Lwt.return_ok ())
  |> function
  | Ok () -> ()
  | Error err -> failwith (Caqti_error.show err)
;;
