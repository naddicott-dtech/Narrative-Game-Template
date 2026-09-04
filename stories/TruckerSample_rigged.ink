// LONG HAUL: LOS ANGELES TO NEW YORK — RIGGED FOR GODOT
// The same story as TruckerSample.ink, plus Godot cue tags. A tag is the
// text after a # at the end of a line; Inky shows tags in gray and ignores
// them, and the Godot template turns the ones that start with @ into
// pictures, characters, sounds and cut scenes. See the README.
//
// Student note:
// - Lines beginning with // are comments. Players do not see them.
// - VAR creates a variable that the story remembers.
// - Knots begin with === and stitches begin with =.
// - A divert such as -> road_menu sends the story somewhere else.
// - A + choice is reusable. This matters in a repeating game loop.


// -----------------------------------------------------------------------------
// GLOBAL VARIABLES
// -----------------------------------------------------------------------------

// Cargo information
VAR cargo = "None"
VAR insurance_active = true

// Truck and driver resources
VAR fuel = 100
VAR fatigue = 0
VAR elapsed_hours = 0
VAR violations = 0

// Route information
// route_stop starts at 0 (Los Angeles) and ends at 10 (New York City).
VAR route_stop = 0
VAR location_name = "Los Angeles, California"

// Values used while resolving one driving leg
VAR speed_over = 0
VAR travel_hours = 0
VAR fuel_cost = 0
VAR fatigue_gain = 0
VAR police_risk = 0
VAR sleep_risk = 0
VAR event_roll = 0


-> introduction


// -----------------------------------------------------------------------------
// INTRODUCTION AND CARGO SELECTION
// This knot uses stitches to divide one scene into smaller sections.
// -----------------------------------------------------------------------------

=== introduction ===

= opening

LONG HAUL: LOS ANGELES TO NEW YORK

Dispatch has one coast-to-coast run available. Your tractor is fueled, your logbook is open, and New York is a long way east. # @background: warehouse # @music: road_theme # @speaker: dispatcher

First, choose the cargo you will haul. # @speaker: dispatcher

* [Haul avocados in a refrigerated trailer]
    -> avocados_selected

* [Haul cell phones in a sealed dry van]
    -> phones_selected


= avocados_selected

~ cargo = "Avocados"

You back under a refrigerated trailer loaded with California avocados. # @exit: dispatcher

The receiver wants them fresh. If the run takes more than 96 hours, the load will spoil and the contract will be lost.

Speed can save time, but tickets and fatigue can end a run even faster.

-> begin_run


= phones_selected

~ cargo = "Cell phones"

You back under a sealed trailer packed with cell phones. # @exit: dispatcher

The electronics tolerate delay better than produce, but the insurer is strict. Two moving violations will cancel the cargo policy. The delivery contract also expires after 120 hours.

-> begin_run


= begin_run

Your route follows the interstates from Los Angeles through Las Vegas, Albuquerque, Oklahoma City, and St. Louis before the final push to New York City.

Keep an eye on fuel, fatigue, time, and the consequences of speeding.

-> route_dispatch


// -----------------------------------------------------------------------------
// ROUTE DISPATCHER
// The number in route_stop determines which location knot runs next.
// -----------------------------------------------------------------------------

=== route_dispatch ===

{
- route_stop == 0:
    -> los_angeles
- route_stop == 1:
    -> halfway_to_las_vegas
- route_stop == 2:
    -> las_vegas
- route_stop == 3:
    -> halfway_to_albuquerque
- route_stop == 4:
    -> albuquerque
- route_stop == 5:
    -> halfway_to_oklahoma_city
- route_stop == 6:
    -> oklahoma_city
- route_stop == 7:
    -> halfway_to_st_louis
- route_stop == 8:
    -> st_louis
- route_stop == 9:
    -> halfway_to_new_york
- route_stop == 10:
    -> new_york_city
- else:
    -> route_error
}


// -----------------------------------------------------------------------------
// ROUTE LOCATIONS
// Each location is a knot. Several use stitches for arrival text and local
// events. After the location event, the player enters the shared road menu.
// -----------------------------------------------------------------------------

=== los_angeles ===

= arrival

~ location_name = "Los Angeles, California"

The warehouse doors roll shut behind you. Morning traffic crawls across the basin, and the long ribbon of interstate points east. # @background: los_angeles # @transition: fade # @sfx: engine_start

Your manifest reads: {cargo}.

-> road_menu


=== halfway_to_las_vegas ===

= arrival

~ location_name = "halfway to Las Vegas"

The city haze is gone. Sunlight flashes off windshields, dry mountains crowd the horizon, and the desert offers very little shade. # @background: desert # @transition: fade

-> desert_note

= desert_note

The next reliable fuel stop is in Las Vegas. This is a good place to check the gauge before continuing.

-> road_menu


=== las_vegas ===

= arrival

~ location_name = "Las Vegas, Nevada"

Casino towers glow beside the highway even in daylight. Delivery vans, tour buses, and impatient commuters squeeze around your rig. # @background: las_vegas # @transition: fade

-> city_event

= city_event

Traffic near the Strip costs you one hour, but you make it through without leaving the freeway.

~ elapsed_hours = elapsed_hours + 1

{cargo == "Avocados":
    The reefer unit hums steadily behind the cab. The avocados are still cold.
- else:
    The cell-phone trailer seal is still intact.
}

-> road_menu


=== halfway_to_albuquerque ===

= arrival

~ location_name = "halfway to Albuquerque"

You cross the high desert under an enormous sky. Red cliffs and long grades replace the lights of Nevada. # @background: high_desert # @transition: fade

-> road_menu


=== albuquerque ===

= arrival

~ location_name = "Albuquerque, New Mexico"

The Sandia Mountains rise beyond the city. A sign directs commercial trucks toward an open inspection station. # @background: albuquerque # @transition: fade # @scene: inspection_cutscene

-> inspection

= inspection

The inspector checks your lights, tires, and paperwork. Everything passes, but the inspection costs one hour. # @speaker: inspector

~ elapsed_hours = elapsed_hours + 1

{violations > 0:
    The inspector notices the ticket already listed in your log. "Keep it legal from here on," she says.
- else:
    Your driving record is still clean.
}

-> road_menu


=== halfway_to_oklahoma_city ===

= arrival

~ location_name = "halfway to Oklahoma City"

The road stretches across the Texas Panhandle. Wind shoves at the side of the trailer, and tumbleweeds skip across the shoulder. # @background: panhandle # @transition: fade # @exit: inspector

-> road_menu


=== oklahoma_city ===

= arrival

~ location_name = "Oklahoma City, Oklahoma"

Dark clouds pile up ahead of you. Rain drums on the cab while traffic slows beneath the highway interchanges. # @background: oklahoma_city # @transition: fade # @sfx: thunder

-> storm_delay

= storm_delay

The thunderstorm adds two hours to the trip. Pulling over would have taken longer, but pushing through would have been dangerous.

~ elapsed_hours = elapsed_hours + 2

{fatigue >= 7:
    The hiss of the wet pavement is hypnotic. You badly need rest.
- else:
    You stay alert and leave the worst of the storm behind.
}

-> road_menu


=== halfway_to_st_louis ===

= arrival

~ location_name = "halfway to St. Louis"

Fields roll past in every direction. Grain elevators and water towers mark towns too small to appear on your route sheet. # @background: fields # @transition: fade

-> road_menu


=== st_louis ===

= arrival

~ location_name = "St. Louis, Missouri"

The Gateway Arch appears through the windshield. Brake lights stack up near the Mississippi River crossings. # @background: st_louis # @transition: fade

-> bridge_traffic

= bridge_traffic

Construction funnels several lanes into one. Crossing the river costs two hours.

~ elapsed_hours = elapsed_hours + 2

{cargo == "Cell phones" and not insurance_active:
    With the cargo policy canceled, every bump and sudden stop feels expensive.
}

{cargo == "Avocados" and elapsed_hours >= 72:
    The reefer is working, but the delivery clock is becoming uncomfortable.
}

-> road_menu


=== halfway_to_new_york ===

= arrival

~ location_name = "halfway to New York City"

The Appalachian grades make the engine work. The East Coast is close now, but steep roads and dense traffic still stand between you and the receiver. # @background: mountains # @transition: fade

-> final_note

= final_note

This is the last place to rest or refuel before the final driving leg.

-> road_menu


// -----------------------------------------------------------------------------
// THE CORE GAMEPLAY LOOP
// Every location uses this same knot. Its stitches hold the status display,
// choices, and the outcomes of resting and refueling.
// -----------------------------------------------------------------------------

=== road_menu ===

= check_deadlines

// Resting and city delays also consume time, so deadlines are checked whenever
// the menu opens—not only after driving.

{cargo == "Avocados" and elapsed_hours > 96:
    -> spoiled_avocados
}

{cargo == "Cell phones" and elapsed_hours > 120:
    -> late_phones
}

-> status


= status

LOCATION: {location_name}
CARGO: {cargo}
FUEL: {fuel} percent
FATIGUE: {fatigue}
ELAPSED TIME: {elapsed_hours} hours
MOVING VIOLATIONS: {violations}

{cargo == "Cell phones":
    {insurance_active:
        CARGO INSURANCE: Active
    - else:
        CARGO INSURANCE: Canceled
    }
}

{fuel <= 25:
    WARNING: The fuel level is low.
}

{
- fatigue >= 8:
    WARNING: You are struggling to keep your eyes open. Rest before driving.
- fatigue >= 5:
    You are getting tired. Another driving leg will be risky.
- else:
    You feel alert enough to drive.
}

{cargo == "Avocados" and elapsed_hours >= 72:
    WARNING: The avocado delivery is approaching its 96-hour spoilage limit.
}

{cargo == "Cell phones" and elapsed_hours >= 96:
    WARNING: The cell-phone contract expires after 120 hours.
}

-> actions


= actions

{fuel == 0:
    The tank is empty. You must refuel before driving.
}

What will you do?

+ [Rest for 8 hours]
    -> rest

+ [Refuel the truck]
    -> refuel

+ {fuel > 0} [Continue driving]
    -> drive.choose_speed


= rest

You park in a legal space, close the curtains, and sleep for eight hours. # @background: motel # @transition: fade

~ elapsed_hours = elapsed_hours + 8
~ fatigue = 0

You wake up rested.

-> check_deadlines


= refuel

You pull up to the diesel pumps. Filling both tanks takes one hour. # @background: truck_stop # @transition: fade

~ elapsed_hours = elapsed_hours + 1
~ fuel = 100

The gauge reads full.

-> check_deadlines


// -----------------------------------------------------------------------------
// DRIVING AND RANDOM EVENTS
// The first stitch asks for speed. Later stitches calculate costs and events.
// Faster choices save time, but consume more fuel, add more fatigue, and make a
// speeding stop more likely.
// -----------------------------------------------------------------------------

=== drive ===

= choose_speed

How fast will you drive on the next leg?

+ [Drive at the posted speed limit]
    ~ speed_over = 0
    ~ travel_hours = 6
    ~ fuel_cost = 16
    ~ fatigue_gain = 2
    ~ police_risk = 0
    -> prepare_trip

+ [Drive 5 mph over the limit]
    ~ speed_over = 5
    ~ travel_hours = 6
    ~ fuel_cost = 17
    ~ fatigue_gain = 3
    ~ police_risk = 10
    -> prepare_trip

+ [Drive 10 mph over the limit]
    ~ speed_over = 10
    ~ travel_hours = 5
    ~ fuel_cost = 19
    ~ fatigue_gain = 4
    ~ police_risk = 30
    -> prepare_trip

+ [Drive 20 mph over the limit]
    ~ speed_over = 20
    ~ travel_hours = 4
    ~ fuel_cost = 23
    ~ fatigue_gain = 6
    ~ police_risk = 65
    -> prepare_trip


= prepare_trip

You merge onto the highway and settle in for the next leg. # @background: highway # @sfx: engine_start

{speed_over == 0:
    You hold the truck at the posted limit.
- else:
    You run {speed_over} mph over the posted limit.
}

// Apply the predictable costs of this driving leg.
~ elapsed_hours = elapsed_hours + travel_hours
~ fuel = fuel - fuel_cost
~ fatigue = fatigue + fatigue_gain

// If the fuel calculation reaches zero or less, the truck runs dry.
{fuel <= 0:
    -> out_of_fuel
}

-> check_sleep


= check_sleep

// The more tired the driver is, the greater the chance of falling asleep.
// Later conditions replace the smaller risk with a larger one.
~ sleep_risk = 0

{fatigue >= 5:
    ~ sleep_risk = 5
}

{fatigue >= 7:
    ~ sleep_risk = 20
}

{fatigue >= 9:
    ~ sleep_risk = 50
}

{fatigue >= 11:
    ~ sleep_risk = 80
}

~ event_roll = RANDOM(1, 100)

{event_roll <= sleep_risk:
    -> fell_asleep
}

The miles roll beneath you, and you remain awake.

-> check_police


= check_police

// A legal speed has no speeding-ticket risk. Each faster choice raises it.
~ event_roll = RANDOM(1, 100)

{event_roll <= police_risk:
    Red and blue lights appear in your mirror. A highway patrol officer pulls you onto the shoulder. # @sfx: siren

    "I clocked you at {speed_over} over," the officer says. # @speaker: officer

    ~ violations = violations + 1
    ~ elapsed_hours = elapsed_hours + 2

    The ticket and roadside stop cost two hours. # @exit: officer

    {cargo == "Cell phones" and violations >= 2 and insurance_active:
        ~ insurance_active = false
        Your insurer sends an automatic notice: the high-value cargo policy has been canceled because of your driving record.
    }
- else:
    {speed_over > 0:
        You see a patrol car in the median, but it stays put.
    - else:
        A patrol car watches traffic. You pass it at a legal speed.
    }
}

-> check_road_event


= check_road_event

// This small random event adds variety without adding another resource.
~ event_roll = RANDOM(1, 100)

{
- event_roll <= 12:
    A crash ahead closes one lane. Stop-and-go traffic costs two hours. # @sfx: horn
    ~ elapsed_hours = elapsed_hours + 2
- event_roll <= 24:
    Strong headwinds make the truck work harder. You use 4 extra percent fuel.
    ~ fuel = fuel - 4
- else:
    The road ahead remains clear.
}

{fuel <= 0:
    -> out_of_fuel
}

-> advance_route


= out_of_fuel

The engine coughs. The fuel gauge drops to zero, and the truck rolls onto the shoulder.

~ fuel = 0

You wait for roadside service. A tow truck brings enough help to move you to the next route stop, but the delay costs eight hours.

~ elapsed_hours = elapsed_hours + 8
~ fatigue = fatigue + 1

-> advance_route


= advance_route

~ route_stop = route_stop + 1

-> check_cargo_after_drive


= check_cargo_after_drive

{cargo == "Avocados" and elapsed_hours > 96:
    -> spoiled_avocados
}

{cargo == "Cell phones" and elapsed_hours > 120:
    -> late_phones
}

-> route_dispatch


// -----------------------------------------------------------------------------
// NEW YORK AND ENDINGS
// -----------------------------------------------------------------------------

=== new_york_city ===

= arrival

~ location_name = "New York City, New York"

The skyline rises ahead. After one final crawl through city traffic, you back into the receiver's loading dock. # @background: new_york # @transition: fade

-> delivery_result


= delivery_result

{cargo == "Avocados":
    -> avocado_delivery
- else:
    -> phone_delivery
}


=== avocado_delivery ===

The receiver opens the refrigerated trailer and checks the load.

{elapsed_hours <= 80:
    The avocados are cold, firm, and early. Dispatch calls it an excellent run.
- else:
    The avocados are still saleable. You made the deadline with little time to spare.
}

FINAL TIME: {elapsed_hours} hours
FINAL FUEL: {fuel} percent
MOVING VIOLATIONS: {violations}

You delivered the avocados from Los Angeles to New York. # @scene: delivery_cutscene # @music: off

-> END


=== phone_delivery ===

Workers break the trailer seal and begin unloading pallets of cell phones.

{insurance_active:
    The cargo arrives on time with its insurance coverage intact. Dispatch marks the run complete.
- else:
    The cargo arrives, but its insurance was canceled along the way. Your company accepts the load and schedules a serious meeting about your driving record.
}

FINAL TIME: {elapsed_hours} hours
FINAL FUEL: {fuel} percent
MOVING VIOLATIONS: {violations}
CARGO INSURANCE: {insurance_active: Active|Canceled}

You completed the cell-phone run from Los Angeles to New York. # @scene: delivery_cutscene # @music: off

-> END


=== spoiled_avocados ===

The reefer is still running, but too much time has passed. When the trailer is inspected, the avocados are overripe and unsaleable.

FINAL LOCATION: {location_name}
FINAL TIME: {elapsed_hours} hours

The avocado contract is lost. # @music: off

GAME OVER

-> END


=== late_phones ===

The cell phones are undamaged, but the receiver's 120-hour delivery window has closed. The company has already reassigned the contract.

FINAL LOCATION: {location_name}
FINAL TIME: {elapsed_hours} hours

The load is late. # @music: off

GAME OVER

-> END


=== fell_asleep ===

Your eyelids close for one second too long.

The truck leaves the lane. The run ends on the shoulder in twisted metal and flashing emergency lights. # @scene: crash_cutscene # @music: off

FINAL LOCATION: {location_name}
FATIGUE: {fatigue}

You fell asleep at the wheel.

GAME OVER

-> END


=== route_error ===

The route tracker contains an unexpected value: {route_stop}.

This ending should never appear during normal play. Check every place where route_stop changes.

-> END
