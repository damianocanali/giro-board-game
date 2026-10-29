# Giro online: accounts, social, market and money

This is a plan for the features that need a server: sign-in, a leaderboard, chat, and selling or bidding on plots. It ends with an honest check against Monopoly GO.

## Are we turning into Monopoly GO?

Partly, yes. Some of what we already have is Monopoly GO's engine:

| Already in Giro | Same as Monopoly GO? | Keep, change or drop |
|---|---|---|
| Daily roll limit with a countdown | Yes (their "dice energy") | **Keep, but make it generous.** It paces the game and it's what brings people back. |
| Bet multiplier (×2, ×3, ×5 rolls per throw) | Yes, exactly | **Drop it.** It is a gambling mechanic that makes people burn bought rolls faster. It's the clearest copy. |
| Mystery crate with random rolls | Yes (their sticker packs) | **Drop it, or make it free-only.** Paid random boxes are under legal pressure in several countries. |
| Selling rolls for money | Yes | **Keep, but small.** Rolls should never be the main thing we sell. |
| Building your own block freely | No: in Monopoly GO you only pay to "upgrade" fixed landmarks | Giro's own identity. |
| The city is made of other players' real blocks | No | Giro's own identity, and the strongest idea. |
| Passport stamps from exploring | Only loosely like their sticker albums | Ours, and players love it. Grow it. |
| Shutdowns, heists and attacking other players | Monopoly GO's core loop | **Never add these.** Giro is about visiting, not raiding. |

**Direction:** make Giro a cosy city builder that you explore with dice. People come back to see who visited their block, to collect stamps, to build something beautiful and to take part in seasonal events. They don't come back to gamble or to get revenge.

## What players can buy with real money

Rule: **sell looks, comfort and seasons, never power over other players.** Coins and land can only be earned in play, never bought. That keeps the shared city fair and stops real-money trading of plots.

1. **Giro Pass, monthly (about $4.99).** +10 rolls a day, a monthly skin, a passport cover, and double event tokens. This should become the main source of income.
2. **Holiday packs ($1.99 to $3.99).** These are built now as a demo. Each one has a skin, decorations for your block and some rolls. The event's free reward stays free for everyone.
3. **Cosmetics:** pawn and die skins, **passport covers and stamp ink colours** (players love the passport), building façade themes, monument variants (a golden Eiffel Tower, a Statue of Liberty at night).
4. **Season track, every 8 weeks:** a free lane and a paid lane of rewards. Most rewards are cosmetic, and a few are rolls.
5. **Small roll top-ups**, capped at a few per day, for people who just want to keep playing.
6. **Support the city:** an optional tip jar that plants a tree in a shared park, with every supporter's name on a sign. Charming, and harmless.

Not sold: coins, land, upgrades, and anything random.

## Sign-in and saving progress

- **Sign in with Apple** for the account (it's Apple's own login; the App Store requires it if we ever add Google or Facebook login). Progress is saved on the server, so it survives a new phone.
- **Game Center** for friends, achievements and leaderboards. It's free and Apple runs it.
- Playing without an account stays possible. A guest's progress is moved to the account when they sign in.

## Leaderboards

Weekly boards, reset every Monday, with friends and global tabs:
- **Most visited block:** visits from other players.
- **Explorer:** new stamps this week.
- **Builder:** biggest increase in land value.
- **City vs city:** total points of all players from each home city. This gives people a team without needing chat.

There is deliberately no "richest player" board: it rewards hoarding and paying.

## Social, safely

The App Store has firm rules for anything users create or say to each other (guideline 1.2). Every chat or message feature must have a filter, a way to report and block, and a published contact. Apps with free chat also get an older age rating. So we start with expression that can't be abused, and add free text only for friends.

1. **Postcards (first).** When you visit someone's block, you can send them a postcard: a picture of their block with your stamp and a message picked from a list ("Love your café!", "Your park is beautiful", "See you in Roma"). They can't be abused, and they feel lovely to receive.
2. **Reactions on blocks:** hearts, a "wow" and a "cosy", which can be left once per visit.
3. **Guestbook on your block:** shows the last postcards you received.
4. **Clubs per city:** join a club and share a weekly goal ("visit 500 blocks"). Club chat uses quick phrases and emoji only at first.
5. **Free text chat, later, friends only, for people aged 13 and over:** server-side word filter, report and block on every message, a review queue, and automatic mute for repeated reports. Under-13s never see free text.

Safety basics from day one: report and block everywhere, no sharing of locations or contact details (filtered), no direct messages from strangers, a support email in the app, and a clear privacy policy.

## Selling plots and bidding

Every plot already has a value (built now): location (streets, bus line, how central it is, nearby monuments) plus what stands on it, with upgrades counted.

The market works like this:
- **Coins only.** No real money ever touches land.
- **Selling:** put your plot up with a minimum price. It stays listed for 24 hours. The server keeps a small fee (5%) out of the economy, which slows inflation.
- **Bidding:** other players bid in coins. Each bid must beat the last by 5%, and coins are reserved while the bid stands. A bid in the last 5 minutes adds 5 minutes, so there is no sniping.
- **Offers on any plot:** you can make an offer on a plot that isn't for sale. The owner can accept, decline or ignore it, and it expires after a day. Nobody can be forced to sell.
- **Guards:**
  - No buying from your own alt accounts. This is checked by device and account age, and a new account can't sell in its first week.
  - A price cap of 3× the plot's value.
  - A limit of 1 bid at a time per new player.
- **Your home plot can't be sold**, so nobody ever loses their place in the city.

## What it needs technically

- **Server:** Supabase. It gives a Postgres database, Sign in with Apple, row-level security and edge functions. Alternatively, CloudKit is cheaper but much harder for shared world state and a market.
- **Server-authoritative economy:** coins, rolls, land and bids are decided on the server, never trusted from the phone. This also fixes the clock trick with daily rolls.
- **Moderation:** a word filter in an edge function, plus a report table and a small admin page.
- **Purchases:** StoreKit 2, with receipts checked on the server, or RevenueCat on top.

## Suggested order

1. **Decide:** drop the bet multiplier and the paid crate. This is a small change.
2. Sign in with Apple, cloud save and Game Center leaderboards.
3. Real shared city: other players' blocks and visits become real.
4. Postcards, reactions and the guestbook.
5. Giro Pass and holiday packs with real StoreKit purchases.
6. Plot market with bids.
7. Clubs, then friends-only chat with full moderation.

## Decisions needed from you

- Drop the bet multiplier and the paid crate? **Recommended: yes.**
- Supabase or CloudKit for the server? **Recommended: Supabase.**
- Minimum age: 13 and up, with no free chat for younger players? **Recommended: yes.**
