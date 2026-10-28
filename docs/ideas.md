# Giro: feature and monetisation ideas

A brainstorm, not a plan. Items are grouped by what they are for, and each group starts with what I'd do first.

## What the game is today

You roll a die and drive your pawn through a city made of other players' blocks. Every street square does what the building beside it does. You collect coins, buy land and build your own block, which pays you when others pass through. You get 30 free rolls a day.

The strongest idea in Giro is that **other players' cities are the board**. Most of the features below try to make that feel real.

## Make the game better

### Feel and feedback (cheap, big effect)
- **Sound effects.** Dice clatter, a coin "ding", a cash-register sound on payday, a drum roll for plaza duels, a bus horn.
- **Juice on big moments.** A small camera shake when the die lands, confetti for a finished mission, a coin shower for paydays.
- **Guided first game.** The first three rolls are scripted to show a coin square, a fork and a park. The first build is free.
- **Day and night.** The city follows the real clock: lights in windows at night, longer shadows in the evening.

### Reasons to come back every day
- **Login streak.** A seven-day calendar of rewards: rolls, coins, then a skin on day 7. Missing a day resets it to day 1, not to zero rewards.
- **Weekly events.** "Café week" doubles café payouts, "Rush hour" makes buses free, "Treasure hunt" hides extra coins.
- **Passport albums.** Stamps fill themed albums ("Every park", "Ten cities"). A full album gives a rare skin or building.
- **Missions with streaks.** Finish all daily missions three days in a row for a bonus crate.

### Deeper building
- **Block levels.** Spend coins to upgrade a building. Higher levels pay more per visit and look fancier.
- **Districts.** Owning blocks next to each other unlocks a bonus, like Monopoly colour sets.
- **Building themes.** Venetian, Tokyo, Wild West or Futuristic façades for your block. These are also good to sell (see below).
- **Drag to paint.** Paint several squares in one stroke in build mode.

### Real multiplayer (the big one)
- **Your block lives in other people's games.** Real players drive past your shop and you earn while you sleep. This is the core promise and needs a backend.
- **Visit notifications.** "Marta from Milan stopped at your café: +24 coins." This is the best reason to open the app.
- **Friends.** Add friends, put their blocks next to yours, gift them rolls once a day.
- **Weekly leaderboard.** Richest block, most stamps, most duels won, using Game Center.
- **Clubs.** Teams of up to 20 share a weekly goal, such as "visit 500 blocks together", for a shared reward.
- **Real duels.** Plaza duels against the block owner's best score, not just a random roll.

### More to do on the board
- **Mini-games on plazas.** Higher or lower, dice poker, or a quick memory game instead of a single dice duel.
- **Chance cards.** A few squares draw a card: "Road works, go back 3", "Street festival, everyone pays you 5".
- **Taxi and train.** Rarer, faster shortcuts than the bus.

## Make money

Guiding rule: **sell time and looks, never winning.** Players accept paying to play more or to look good. They leave when money buys power over other players. Apple also requires the odds for random rewards to be shown, which the crate already does.

| Idea | How it pays | Notes |
|---|---|---|
| **Roll packs** | One-off purchases, like the current demo shop. | Fits the daily limit naturally. Already designed. |
| **Rewarded ads** | Watch a short ad for 5 rolls, up to 3 times a day. | Earns from players who never pay. No forced ads between rolls. |
| **Refill now** | Skip the midnight countdown for coins or a small payment. | Shown right on the "New rolls in" card. |
| **Giro Pass (monthly)** | Subscription: +15 rolls a day, the golden skin, double mission rewards. | Steady income. Replace the current one-off "pass" with a real subscription. |
| **Season track** | A free and a paid lane of rewards over 6 to 8 weeks. | Each season brings themed skins and buildings. |
| **Cosmetics** | Skins, dice, pawn trails, building themes, block decorations. | Pure looks. Price the best ones only for money, the rest for coins. |
| **Starter pack** | A one-time cheap bundle on day 2: rolls, coins and a skin. | Usually the best-converting offer in mobile games. |
| **No ads** | One-time purchase that removes the ad buttons and gives their rolls for free. | For players who dislike ads. |

Ideas to avoid, or leave for later:
- **Interstitial ads** between rolls. They interrupt the best moment of the game.
- **Selling land or coins that beat other players.** It breaks the shared city.
- **Sponsored real-world brands on squares.** Possible one day, but only once there are many players.

## Technical notes for these features

- **Purchases:** use StoreKit 2, or RevenueCat on top of it if you want dashboards and easy subscriptions.
- **Ads:** AdMob or AppLovin MAX for rewarded ads. They need Apple's tracking permission prompt and a privacy label.
- **Fair daily rolls:** today the refill uses the phone's clock, so changing the clock gives free rolls. Once there is a backend, the server should decide when the next refill is due.
- **Backend for multiplayer:** CloudKit is the cheapest to start with (free, Apple accounts only). Supabase or Firebase work if Android ever matters.

## Suggested order

1. Sound effects and juice, plus the guided first game.
2. Real purchases with StoreKit (roll packs, refill now, starter pack), then rewarded ads.
3. Login streak and weekly events.
4. Multiplayer backend with visit notifications.
5. Giro Pass subscription and seasons, once there is enough content to fill them.
