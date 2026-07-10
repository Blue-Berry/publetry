let () =
  Lwt_main.run
    (let open Lwt_result.Syntax in
     let* db = Db.connect "sqlite3:./publetry.db?mode=ro" in
     let* harvest = Db.search_title db "Harvest Home" in
     assert (List.exists (fun Db.{ title; _ } -> title = "Harvest Home") harvest);
     let* herrick = Db.search db "Robert Herrick" in
     assert (List.length herrick > 0);
     let* authors = Db.search_authors db "Robert" in
     assert (List.mem "Robert Herrick" authors);
     let* titles = Db.search_title db "Harvest Home" in
     assert (List.length titles > 0);
     let* filtered = Db.search_title db ~author:"Robert Herrick" "Harvest" in
     assert (List.length filtered > 0);
     assert (List.for_all (fun Db.{ author; _ } -> author = "Robert Herrick") filtered);
     let* herrick_author = Db.search_author db "Robert Herrick" in
     assert (List.length herrick_author > 0);
     let* titles = Db.search_titles db "Harvest" in
     assert (List.mem "Harvest Home" titles);
     let* found = Db.find db ~author:"Robert Herrick" ~title:"Harvest Home" in
     assert (Option.is_some found);
     let* poems = Db.find_by_author db "Robert Herrick" in
     assert (List.length poems > 0);
     Lwt.return_ok ())
  |> function
  | Ok () -> ()
  | Error err -> failwith (Caqti_error.show err)
;;
