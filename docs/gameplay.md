# Playing beach volleyball

[Back to the README](../README.md) · [Build and verification](development.md)

Choose **Practice → Serve** in the arrival menu, then hold and release **LMB**
near the top of the toss. Press **Escape** or **F1** to return to the menu.
**H** shows all court controls.

## Game menu

The menu opens after the court loads. **Escape** or **F1** opens it again;
**Escape** and right-click go back a page, then return to the court. Mouse
buttons activate on release, so dragging off a button cancels it. Arrows move
to the next item in that direction; **Tab** / **Shift + Tab** follows reading
order. **Enter** selects, and **Q / E** changes tabs. Left/right adjusts a
focused setting or selects an adjacent match length or HUD style. Sliders also accept a
click or drag. Left turns a switch off; right turns it on.

- **Play:** a single Beach doubles card summarizes your match before you start.
  Choose 7, 11, or 21 points; games are win by two. After entering the court,
  **Resume** becomes the default action with the live score and current rules.
  **New match** opens its own length choice; changing that choice keeps the
  active match's rules. A completed match offers **Play again**.
- **Practice:** serving, passing, setting, attacking, or unstructured free play.
- **Settings:** **Gameplay** groups contact assistance, the landing guide, and
  contact camera motion. **Audio & Video** groups volume, mouse speed, and field
  of view. Each option explains its effect; changes appear immediately. Court
  options apply to your current player, and another session keeps them. New
  players start with manual contact and the landing guide off. **HUD** has
  separate switches for the court map, coaching tips, and shot details. All
  three start off. The **Minimal**, **Classic**, and **Competitive** gallery
  shows the actual scoreboard styles and applies your choice immediately.
  Your HUD choices are saved for future launches.
- **Learn:** a three-step first serve guide, with **Try a serve** taking you
  directly into serve practice. **All controls** returns to court with the
  full control overlay open.

Controller **stick / D-pad / A / B** follows the same navigate, select, and back model.
Opening the menu cancels a prepared shot or block. The court stays live with a
gentle camera drift while browsing; your original view returns on exit.
Changing sessions during doubles asks before resetting the score; quitting
also asks. Confirmations name the destination, show your current session, and
default to **Cancel**. The quiet **Controls** footer opens the on-court guide;
**Settings → Audio & Video → Advanced video & input** opens QSS-M's video,
audio, and binding menus. **F12** always reaches the console.
The first-serve invitation disappears after starting three matches, and the
navigation hints disappear after five court visits.
To skip the arrival menu on future launches, enter `seta bv_menu_auto 0` in
that console. Use `seta bv_menu_auto 1` to restore it.

## Controls

| Input | Action |
| --- | --- |
| WASD / mouse | Move / look |
| Hold and release LMB | Prepare and contact a forearm pass or high attack |
| Hold and release RMB | Prepare and contact a set, or an airborne roll shot |
| Hold RMB + Space near the net | Face the net and jump to block an opponent's attack |
| Wheel up / down | Increase / decrease arc in 5% steps |
| Hold Q / E | Adjust remembered sidespin left / right continuously |
| Z | Cycle topspin/backspin; positive values dip, negative values lift |
| F / V | Bias placement shorter / deeper; soften / firm up a receive |
| B | Reset placement depth to neutral |
| Middle mouse | Reset sidespin and restore moderate topspin |
| Shift + mouse | Change shot direction while preparing |
| Space | Jump; release between jumps |
| Ctrl | Dive in your movement direction; recovery has a short cooldown |
| R / T | Ready a serve / feed another ball |
| G | Select float or topspin jump serve; also selects the receive drill's serve |
| 1 / 2 / 3 / 4 | Leave doubles and enter serve / receive / setting / attack practice |
| 5 | Start or restart local doubles |
| C | Toggle assisted contact while holding a shot |
| J | Toggle the landing guide |
| H / Tab | Toggle help / hold for help |
| Escape / F1 | Open the game menu |
| F12 | Console |

Aim before holding a shot button. Preparation stores your direction, allowing
you to look upward and track the ball. Hold Shift while preparing to change
that direction. For a cut, use **F** to bias an attack short, then turn the
stored heading more than about 20° with **Shift + mouse** during preparation.
Turning to the hitting side selects the wrist-away follow-through; the other
direction selects the inward cut. Spin controls the subsequent curve separately.

Release when the ball reaches your hands. With C assistance enabled, you can
keep holding: contact happens automatically only in the centre of physical hand
reach after preparation, with the same obstruction and recovery checks. This
is optional in both doubles and practice; new players start with manual contact.
Manual release retains the wider hand window and allows the best receive timing.
Assisted receives have a timing grade capped at 60%. Assistance never moves the
ball or your feet.

The reticle and timing cue turn green when the ball is within physical reach,
using the same obstruction checks as
contact. A brief contact window helps catch balls moving between server frames;
it still requires physical reach. Centred contacts give clean power and control;
reaching toward the edge of your hands produces softer, glancing shots.
Glances deflect toward the reach consistently. Receives rebound from incoming
ball velocity rather than charging a chosen outgoing speed.
Preparing early and planting your feet improves contact quality. Footing recovers
over about a quarter-second after you stop; jump attacks retain takeoff footing,
while dives provide an emergency save with reduced control.

Normal shot power fills over 0.75 seconds. Receiving is different: aim your
forearm platform toward your teammate, choose lift with the wheel, then release
as the ball reaches the hands. The clean timing band is about 35 ms either side
of closest approach, with a gradual penalty outside it. Preparing early helps
read the descending approach; Shift updates that read and your stored aim when
the ball drifts. Plant before contact. F softens the platform to absorb pace;
V makes the rebound firmer and longer. Holding longer does not increase receive
power. Overhead first contacts use the same timing and incoming-energy model.
Poor timing, a stretched reach or the wrong platform can shank or overpass.

F/V changes placement depth separately
from that power and the wheel arc. Short/deep attacks change launch angle while
preserving arm speed, allowing a hard short cut. Passes, sets, rolls, and serves
change forward travel; sets retain their selected vertical lift. B restores
neutral depth. This is a placement bias, so movement, spin, net collisions,
and contact quality still affect the actual landing.

The default HUD keeps the court open: a compact score or practice badge, a
small aiming dot, and one short cue when serving, preparing, or finishing a
point. A thin power or timing bar appears only while preparing. Ordinary
doubles rallies have no permanent instruction panel. Practice contact and
landing feedback share the bottom cue and fade after 2.4 seconds; preparing
the next shot takes priority.

Open **Settings → HUD** to add information when you need it:

- **Court map** shows you in white, the ball in gold, your partner in blue,
  and opponents in red. Practice target zones appear here.
- **Coaching tips** adds preparation and positioning advice during play.
- **Shot details** adds arc, spin, placement, practice counts, and shot speed.
  Prediction range and apex appear while preparing with the landing guide on.

These options are independent and off by default. **Gameplay → Landing guide**
or **J** enables the gold landing ring without turning on the map. The ring
previews a centred contact using your preparation, footing, depth and serve
timing; reaching for the ball can change the outcome. With both map and landing
guide on, an outlined green or orange marker shows that prediction on the map.

**H** or **Tab** opens grouped controls on demand. QSS-M's `drawroundedrect` named
CSQC extension supplies native antialiased corners; older engines retain square
panels. The original bitmap font and normal Quake font provide text fallbacks.

Start with a serve: press R, move along the baseline, aim, and hold LMB to toss.
The serve gauge rises toward the toss apex and then falls; the sweet spot is
around 0.45 seconds for a float serve at default gravity. Release around
0.35–0.55 seconds for a standing float, using the timing readout and
SERVE SWEET SPOT cue. Early/late
strikes lose power and control. Timing follows the configured gravity. Try F/V
and wheel arc for short/deep serves; extra depth can send the ball long.

G selects the serve type before the toss. FLOAT uses a hard, low-spin contact
with bounded lateral and vertical drift. Adding substantial Q/E sidespin
suppresses the float effect. TOPSPIN uses a higher toss with forward spin and
a faster downward bend. Jump about 0.1 seconds after the toss and strike around
its 0.48-second apex for the fastest contact; a standing topspin contact loses
pace. The type sets forward spin for serves; Z still controls other strokes. The opponent
mixes serve types between points. Receive drill (2) uses the G selection.
The model rotates about the same world spin axis used by the flight forces.
Float movement is a deterministic wake approximation with a new phase per
serve, shared by live flight and previews. These are game-feel mechanics, not
a ball- or wind-tunnel-calibrated aerodynamic model.

Passes, sets, spikes, rolls, serves, and digs have distinct original contact
sounds and a small camera pulse. Set `bv_contact_kick 0` in the console to
disable the pulse, or use a value between 0 and 1 to reduce it.

Drills automatically feed another ball shortly after landing. Setting feeds
drop near you; attack mode moves you near the net. You can also set to yourself
and then attack. You can hold a shot early while waiting for an automatic feed;
the feed preserves your preparation and aim. R and manual feeds clear the old
contact window. A flight that lasts longer than eight seconds expires so a ball
caught on the tape cannot stall practice. Expired flights count as misses.
The sand stays clear inside the blue boundary, with a matching center line
under the net. Practice target zones appear on the optional court map instead
of being painted on the court. Brief feedback reports target hits, in/out,
misses, and under-net faults; optional shot details show speed in metres per
second. Consecutive self contacts are allowed for practice.

![Clear sand inside the blue court boundary and a center line under the net in QSS-M](court.png)

## Doubles rallies

Press **5** to start. The opponents serve first; move into the incoming ball,
prepare LMB toward your blue teammate and release at the hands, then get forward
for their set. The compact scoreboard shows both teams and a serving-side dot.
Optional coaching tips call out receive, set, attack, block or cover. Both
opponents use the same physical receive–set–attack sequence. Bots forecast the
ball's flight, move with collision-aware feet, prepare and strike only within
hand reach. Poor positioning can cause a miss.

At attack contact, bots simulate nine short/deep and angled spike/roll options
with the current wind, drag, spin and contact quality. They reject predicted
net and court faults, then compare when each defender could intercept the
descending ball, including a committed block's hand volume and remaining jump
window. A cut outside the hands or a roll above them can beat the block. Both defenders affect placement. This is an approximate
reach estimate; collisions, dives and changes of direction can still save a shot.

Receivers can make an emergency dive when ordinary movement would arrive late
and a low dig is physically reachable. A dive commits to its original direction,
lowers control and costs recovery time even when it misses. A recovering teammate
also affects which player takes the next incoming ball. Repeated contacts require
the ball to leave the original hand volume as well as the recovery timer to expire.

Aim receives toward your teammate and use F to cushion incoming pace. Ordinary
passes and sets use short depth (F); use B to restore neutral depth for the attack. Wheel arc changes
the height. The direction is yours to choose, including on assisted contacts.
Jump + LMB attacks high balls; jump + RMB gives a slower looping roll shot.
Shot-specific follow-through briefly limits movement and prevents instant
recontacts. A small ball shadow helps read height even with J overlays off.

### Blocking and coverage

When the opponents prepare an attack, take the net or cover behind your partner.
Face the net within roughly a metre, **hold RMB**, and **jump with Space** as the
attack arrives. The raised hands physically rebound incoming pace; holding
longer adds no power. Your jump has a short contact window, so an early jump
opens the court to a delayed roll. Releasing RMB lowers the hands. RMB keeps
its set/roll action during your team's possession and when receiving a serve.

The front bot takes the block and the other player covers the open diagonal.
If you prepare a block, your blue partner covers behind you. Bots read the
visible set and commit their lane when they jump; they cannot track a late cut
across the court in midair. Watch the hands before choosing a spike, short cut,
or lofted roll. Court coverage returns to ordinary receiving after the ball
crosses, so the defender can move in for a short dig.

A beach block counts as **touch one**, leaving two touches. The blocker may
play the next ball after it separates from the hands; subsequent contacts use
the ordinary double-contact rule. Serves cannot be blocked, and a block sent
out is charged to the blocking team. These rules follow
[FIVB beach rules 14.4–14.5](https://www.fivb.com/wp-content/uploads/2025/02/FIVB-BeachVolleyball_Rules2025_2028-EN-v01.pdf).
This implementation contacts the ball on the defender's side of the net;
over-net penetration and collective blocks are not simulated.

The default match is first to seven, win by two. The winner serves next after
a two-second pause; you serve home points and the far back bot serves away
points. Press 5 to restart or 1–4 to return to practice. R/T practice resets are
inactive during doubles. `bv_match_points` sets the next match's target (3–21),
and `bv_bot_speed` adjusts bot movement (80–220 units/second, default 155).
This mode is for one local human player; it does not provide network 2v2 slots.

## Physics and tuning

The court uses 32 units per metre: 16×8 metres, a 2.43-metre net, and a
21.25-centimetre ball. Ball integration runs at 120 Hz with retained fractional
time. Ground and net collisions are swept; the net uses a thin panel expanded
by the ball radius, including vertical and overlapping contacts. A ball cannot
fit through the 10-centimetre mesh openings. Posts and antennas use swept
sphere-versus-capsule collision with rounded tips.
Hand contacts are checked before the first obstacle, and under-net faults are
limited to crossings within the net's width before the ball lands. Prediction
and live play share the same integrator and net response.

The console exposes `bv_gravity`, `bv_drag`, `bv_magnus`, `bv_spin_decay`,
`bv_wind_x`, and `bv_wind_y`. Wind values use units/second; 32 is 1 m/s.
Gravity defaults to 313.92 units/second². Player gravity follows the ball's
gravity, while `server.cfg` sets sand movement speed, acceleration, and friction.
Human and bot jumps lift the feet 65 cm, with takeoff speed scaled to gravity.
At the apex the eyes stay below the tape and overhead hands reach about 3.06 m.
For a jump topspin serve, toss first and jump shortly afterward; at default
gravity the toss peaks around 0.48 seconds and the jump around 0.36 seconds.
Shot velocity recipes are in `src/player.qc`, `src/serve.qc` and `src/receive.qc`; aerodynamic forces are in
`src/physics.qc`. The preview includes floor, net, post and antenna interactions
using the same equipment response as live play; other surroundings are traced
during live play.
