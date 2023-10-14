local Translations = {
    error = {
        ["cancled"] = "Abgebrochen",
        ["no_truck"] = "Du hast keinen Lastwagen!",
        ["not_enough"] = "Nicht genug Geld (%{value} benötigt)",
        ["too_far"] = "Du bist zu weit entfernt vom Abgabeort",
        ["early_finish"] = "Aufgrund des vorzeitigen Endes (Abgeschlossen: %{completed} Gesamt: %{total}) wird deine Kaution nicht zurückerstattet.",
        ["never_clocked_on"] = "Du hast dich nie eingeloggt!",
        ["all_occupied"] = "Alle Parkplätze sind belegt",
    },
    success = {
        ["clear_routes"] = "Benutzer-Routen wurden gelöscht (%{value} gespeicherte Routen)",
        ["pay_slip"] = "Du hast $%{total} erhalten, deine Abrechnung von %{deposit} wurde auf dein Bankkonto überwiesen!",
    },
    target = {
        ["talk"] = 'Mit dem Müllmann sprechen',
        ["grab_garbage"] = "Müllsack aufheben",
        ["dispose_garbage"] = "Müllsack entsorgen",
    },
    menu = {
        ["header"] = "Hauptmenü Müllabfuhr",
        ["collect"] = "Gehalt abholen",
        ["return_collect"] = "Lastwagen zurückbringen und Gehalt hier abholen!",
        ["route"] = "Route anfordern",
        ["request_route"] = "Müllabfuhr-Route anfordern",
    },
    info = {
        ["payslip_collect"] = "[E] - Gehaltsabrechnung",
        ["payslip"] = "Gehaltsabrechnung",
        ["not_enough"] = "Du hast nicht genug Geld für die Kaution.. Kaution beträgt $%{value}",
        ["deposit_paid"] = "Du hast $%{value} Kaution bezahlt!",
        ["no_deposit"] = "Du hast keine Kaution für dieses Fahrzeug hinterlegt..",
        ["truck_returned"] = "Lastwagen zurückgebracht, hol deine Gehaltsabrechnung ab, um dein Gehalt und deine Kaution zurückzuerhalten!",
        ["bags_left"] = "Es sind noch %{value} Müllsäcke übrig!",
        ["bags_still"] = "Es ist noch %{value} Müllsack da!",
        ["all_bags"] = "Alle Müllsäcke sind erledigt, fahre zur nächsten Stelle!",
        ["depot_issue"] = "Es gab ein Problem am Depot, bitte kehre sofort zurück!",
        ["done_working"] = "Du hast deine Arbeit beendet! Gehe zurück zum Depot.",
        ["started"] = "Du hast mit der Arbeit begonnen, Standort auf dem GPS markiert!",
        ["grab_garbage"] = "[E] Einen Müllsack aufheben",
        ["stand_grab_garbage"] = "Steh hier, um einen Müllsack aufzuheben.",
        ["dispose_garbage"] = "[E] Müllsack entsorgen",
        ["progressbar"] = "Müllsack im Müllwagen verstauen...",
        ["garbage_in_truck"] = "Lege den Müllsack in deinen Lastwagen..",
        ["stand_here"] = "Steh hier..",
        ["found_crypto"] = "Du hast einen Cryptostick auf dem Boden gefunden",
        ["payout_deposit"] = "(+ $%{value} Kaution)",
        ["store_truck"] =  "[E] - Müllwagen abstellen",
        ["get_truck"] =  "[E] - Müllwagen holen",
        ["picking_bag"] = "Müllsack wird aufgehoben..",
        ["talk"] = "[E] Mit dem Müllmann sprechen",
    },
}

if GetConvar('qb_locale', 'en') == 'cs' then
    Lang = Locale:new({
        phrases = Translations,
        warnOnMissing = true,
        fallbackLang = Lang,
    })
end
--translate by stepan_valic