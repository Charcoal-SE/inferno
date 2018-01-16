# Inferno

Inferno is a WIP centralized server for managing StackExchange bots. It listens and fetches new or updated SE content (posts, comments, edits...), dispatches HTTP requests to subscribed bots for scanning, posts reports to chat and to the web dashboard using bot-specified templates, and handles chat commands for the bots.

At its core, Inferno is intended to abstract out the chat and API monitoring concerns, so as to provide a way for bots to isolate their post scanning logic and host it in a serverless environment (such as AWS Lambdas) where it can be called as needed to scan posts. Similar to the previous [apicache](https://github.com/SOBotics/apicache), this also cuts down on overall calls since Inferno will retrieve content only once and dispatch it to all subscribers.

## Bot Interface

Your bots are expected to implement at minimum 2 routes:

- The chat auth route (`"auth_route"`): This route is expected to return a JSON dictionary like so:

```
{
    "stackexchange": {
        "cookie": "...",
        "fkey": "...",
        "id": "...,
    },

    "stackoverflow": {
        "cookie": "...",
        "fkey": "...",
        "id": "...,
    },

    "meta.stackexchange": {
        "cookie": "...",
        "fkey": "...",
        "id": "...,
    },
}
```

  - `"cookie"`: contains the contents of the `sechatusr` cookie, which is given to you after you log in to the given chat host.
  - `"fkey"`: contains the `fkey` for the given host (traditionally retrieved from `/chats/join/favorite`, which also contains `"id"`)
  - `"id"` : contains the bot's user ID for the given host.

In effect, this allows Inferno to post messages on your bot's behalf without actually having its password. If Inferno was ever compromised, a mod could simply invalidate the bot's sessions.

- The scan route (`"types.<type>.query.route"`). This is the actual important route: it takes a dictionary containing API responses like so:

```
{
    "items": [
        ...
    ]
}
```

and returns a classification like so:

```
{
    "items": [
        {
            "spam": true|false,
            ...
        },
        ...
    ]
}
```

or

```
{
    "items": [
        {
            "score": 7.0,
            ...
        },
        ...
    ]
}
```

As you'll see in the Bot Configuration section, the names of the keys can be customized (they don't have to be `"spam"` or `"score"`). This is in effect all the bot has to do -- it's expected that real bots will return other data, such as `"reasons"` or `"why_data"` which will then be used to render the report to chat, but the most bare bones bot simply returns a boolean for each item on whether or not it's interesting.

The only change to this format occurs when the post type is a `"question"` (see `"types"` and `"types.<type>.query.answer_key"` in Bot Configuration for more info). When a question is returned from the API, it also contains a list of answers like so:

```
{
    "items": [
        {
            "answers": [...],
            ...
        },
        ...
    ]
}
```

To indicate that one or more *answers on the question* should be reported, the response is structured like this:

```
{
    "items": [
        {
            "spam": true|false,

            "answers": [
                {
                    "spam": true|false,
                },
                ...
            ]
        }
    ]
}
```

Each of these classifications should be in the index where the corresponding answer was. Answers are not sent in separate requests -- instead, you get a request containing questions and their answers. This cuts down on the number of times your lambda is called.

In addition to these two critical routes, you may also want to create one or more routes to handle remote chat commands (see `commands` in Bot Configuration). The request structure for these hasn't been designed yet, but they're expected to return plain text Markdown that will be posted as a reply to the command.

## Bot Configuration

Aside from dedicated Inferno routes for modifying specific parts of a bot's configuration, the intended way to register or update a bot with Inferno is by posting a JSON configuration blob to `/bots/create` or `/bots/update_json`:

```
{
    "auth_route": "...",

    "types": {
        "questions|comments|edits|suggested_edits|reviews": {
            "sites": "*"|["site name", ..],

            "query": {
                "method": "POST|GET",
                "route": "...",

                "response": {
                    "key": "...",
                    "type": "switch|score",

                    "answer_key": "...",
                    "minimum": 0.0,
                    "reasons_key": "..."
                }

                "templates": {
                    "chat": "...",
                    "web": "..."
                }
            }
        },
        ...
    },

    "feedbacks": {
        "<name of feedback>": {
            "aliases": ["names", ...],
            "icon": "<unicode char>",
            "type": "true|neutral|false",
            "blacklist": true|false,
        },
        ...
    },

    "commands": {
        "<name of command>": {
            "type": "static|local|remote",
            "reply": true|false,
            "data": "..."
        },
        ...
    },


    "rooms": {
        "stackexchange|stackoverflow|meta.stackexchange": {
            "<room id>": {
                "commands": true|false
                "delay": true|false,
                "delete_fp": true|false
                "deletionwatcher": true|false,

                "conditions": {
                    "<key>": {
                        "== | != | < | > | <= | >= | contains | not contain": "<value>",
                        ...
                    }
                }
            },
            ...
        },
        ...
    }
}
```

- `auth_route`: This contains the URI for authenticating the bot to chat (see Bot Interface).

- `types` Contains one or more keys defining the post types this bot is subscribed to:
  - `questions`: This monitors the SE real-time websocket (`155-questions-active`) and reports all questions bumped, **with their answers included.** If you're only interested in answers, subscribe to this anyways and scan only the answers (children of `"answers"` key).

  - `comments`: This polls the API route `/comments` to retrieve new comments at an allocation-dependent rate (see Allocations). This post type does not support the `"sites": "*"` (all sites) option -- you must specify specific sites.

  - `edits`: This monitors the SE real-time websocket for questions as per `questions`, but if a bumped question or answer was edited, will query the `/posts/{ids}/revisions` route to fetch the latest revision of the post.

  - `suggested-edits`: This polls the API route `/suggested-edits` to retrieve new suggested edits at an allocation-dependent rate. This post type does not support the `"sites": "*"` (all sites) option -- you must specify specific sites. Note that many use cases for this post type can also be fulfilled by the `reviews` post type, such as EditMonitor's "accepted by OP with a reject vote" or "1 accept vote and 1 reject vote" -- this should only be used if you need the content of the suggested edit as soon as it is made.

  - `reviews`: This monitors the SE real-time websocket (`<site>-review-dashboard-update`) and reports all reviews made; this does **not** mean that it reports when a post enters a review queue, but rather when a user perform a review. Currently this will report on reviews made in any review queue; this may be changed. This post type also does not support the `"sites": "*"` (all sites) option -- this may change in the future.

- `types.<type>.sites`: This can either be the string `"*"` for all sites, or an array of site names to monitor. Only `questions` and `edits` support `"*"`. Defaults to `"*"` for `questions` and `edits`, and to `["stackoverflow.com"]` for everything else.

- `types.<type>.query`: A dictionary containing information on where to send the reports to for scanning.

- `types.<type>.query.method`: Either POST or GET -- defines the HTTP method employed. (A `WS` method for sending reports via ActionCable may be added). Defaults to `POST`.

- `types.<type>.query.route`: The URI to send the request to. Include the protocol (`http://` or `https://`)

- `types.<type>.query.response`: A dictionary defining the response to expect.

- `types.<type>.query.response.key`: The key in the (JSON) response containing the classification -- this can be a boolean (true it should be reported, false it should not be) or a score (arbitrary float).

- `types.<type>.query.response.type`: `switch` for a boolean classification, `score` for a float classification. Defaults to `switch`.

- `types.<type>.query.response.answer_key`: Required for the `questions` post type. This key is expected to contain an array containing the classifications of each answer e.g.:

```
{
    "items": [
        {
            "is_spam": false,
            "reasons": [],
            ...

            "answers": [
                {
                    "is_spam": true,
                    "reasons": ["Possible Link Only"],
                },
                ...
            ]
        }
    ]
}
```

This is (obviously) expected to be in the same order as the original `answers` array in the request.

- `types.<type>.query.response.minimum`: Required for `score` classification. Specifies the minimum score required to even consider posting the report to a chat room and/or save it to the DB. Specific chat rooms can tweak their own minimum score for chat reports using a condition; this is just the lowest threshold.

- `types.<type>.query.response.reasons_key`: Optional. Marks the given key as containing a list of unique string reasons. The textual representation of these reasons should stay consistent across reports, as they are used to store and track a given reason's accuracy.

- `types.<type>.query.templates`: A dictionary containing the templates for formatting the reports.

- `types.<type>.query.templates.chat`: Required. A format string defining how your bot's chat message reports will appear: `"%{key} ... %{another key} asdf."` The format string can reference keys contained in either the API response (e.g. `link`), your bot's response (e.g. `reasons`) or a few special ones (e.g. `ms_link` for the dashboard entry). For answers, the "API response" will specifically be the corresponding entry under the `answers` array, not the API response of the question.

- `types.<type>.query.templates.web`: Optional. A Handlebars template that will be rendered whenever someone views the post on the dashboard. All of the keys available to the chat template will also be available.

- `feedbacks`: A dictionary defining the feedbacks this bot accepts, whether from chat or from a userscript. The name of each key should be the name of the corresponding feedback, without any modifiers at the end (e.g. `tp`, not `tpu-`).

- `feedbacks.<feedback>.aliases`: Optional. An array containing aliases, or feedback strings that are equivalent to this one. For instance, `vandalism` might have `v` or `vand` as aliases, or `needs edit` might have `ne` as an alias.

- `feedbacks.<feedback>.icon`: Optional. This is (expected to be) a Unicode character of some sort that represents the feedback in the dashboard. We recommend U+2713 (`✓`) for true positives and U+2717 (`✗`) for false positives.

- `feedbacks.<feedback>.type`: Required. Defines the semantics of the feedback:

  - "true": A true positive. This is the only type of feedback that will count as a hit for the reason's accuracy. Conflicts with `false`.
  - "false": A false positive. If the post was autoflagged, this will trigger a chat warning. Conflicts with `true`.
  - "neutral": Anything else (e.g. SmokeDetector's NAA, Natty's needs edit, ...). This won't cause a warning if the post was autoflagged, nor will it conflict with any other feedbacks.

- `feedbacks.<feedback>.blacklist`: Optional, defaults to `false`. Defines whether the feedback affects the user blacklist. If this is `true`, and *the feedback type* is not `"false"`, then the user who created the post will be added to the blacklist. This means that *any* content they produce will automatically be reported with the reason `Blacklisted user`, regardless of what your bot classifies it as. Note that the post will *still be sent to your bot*, and any information from the scan will be available to the templates (e.g. any additional reasons). If *the feedback type* is of type `"false"`, then this feedback will remove the user from the user blacklist instead.

- `commands`: A dictionary defining the commands that this bot accepts. For reply commands, the name of the key should be a prefix *after* the reply ping (:<numbers>) is stripped. For prefix commands, the key will be a prefix of the entire message. This means that for commands that just involve pinging the bot (not replying to it), you need to include the ping e.g. `@Natty alive`. If you want to allow for a shorter prefix, you can use aliases (e.g. `@nat alive`).

- `commands.<command>.type`: Reqiured. Defines the behavior of the command:
  - `"static"`: Replies to the command with the string contained in `"data"`. This is for commands such as `alive` or simple joke commands like `!!/lick`.

  - `"remote"`: Sends the message as a POST request to the URI contained in `"data"`, and replies with the body of the response (in plain text).

  - `"local"`: not designed yet

- `commands.<command>.reply`: If this is `true`, then the command is invoked by replying to one of the bot's messages. The parent message will be included along with the message containing the command itself. Defaults to `false`.

- `commands.<command>.data`: A string. What it contains depends on the type of command.

- `rooms`: A dictionary defining the rooms this bot listens in. This should map the chat host `stackexchange|stackoverflow|meta.stackexchange` to dictionaries that then have the room IDs as keys.

- `rooms.<host>.<room>.commands`: If this is `true`, then Inferno will listen for chat commands in this room. If this is `false`, then only reports will be posted here (commands will not be listened for at all).

- `rooms.<host>.<room>.delay`: If this is `true`, then Inferno will wait 5 minutes before posting a report to this room. You're expected to do this as a courtesy if you run your bot in the Meta Tavern.

- `rooms.<host>.<room>.delete_fp`: If this is `true`, then Inferno will delete reports that are marked as false positives within the message deletion window (2 minutes).

- `rooms.<host>.<room>.deletionwatcher`: If this is `true`, Inferno will listen for when the post reported is deleted and delete the corresponding chat message within the message deletion window (2 minutes).

- `rooms.<host>.<room>.conditions`: This is a dictionary defining the conditions under which a post will be reported to this room. The keys represent keys in either the API or bot response (as with the chat template), and the values are dictionaries defining various predicates.

- `rooms.<host>.<room>.conditions.<key>.==`: If this key exists, then the value of `<key>` is expected to be equal to the specified value.

- `rooms.<host>.<room>.conditions.<key>.!=`: If this key exists, then the value of `<key>` is expected to be *not* equal to the specified value.

- `rooms.<host>.<room>.conditions.<key>.<`: If this key exists, then the value of `<key>` is expected to be less than to the specified value.

- `rooms.<host>.<room>.conditions.<key>.>`: If this key exists, then the value of `<key>` is expected to be greater than to the specified value.

- `rooms.<host>.<room>.conditions.<key>.<=`: If this key exists, then the value of `<key>` is expected to be less than or equal to the specified value.

- `rooms.<host>.<room>.conditions.<key>.>=`: If this key exists, then the value of `<key>` is expected to be greater than or equal to the specified value.

- `rooms.<host>.<room>.conditions.<key>.contains`: If this key exists, then the specified value is expected to be in the value of `<key>` if it is an array.

- `rooms.<host>.<room>.conditions.<key>.not contains`: If this key exists, then the specified value is expected to be not in the value of `<key>` if it is an array.


## Quota Allocation

One of the other features of Inferno is that it "splits" up the total API quota (10,000 requests per day) among the various post types. This can be used to give more/less weight to a given type of post.

There are two kinds of post types, and their behavior with respect to the quota allocation varies:

- Polling. This is `comments` and `suggested-edits`, where an API route is queried periodically to fetch new content. The API allocation defines how often the route is queried: for instance, if you allocate 1,000 requests per day to `suggested-edits`, then it will query for suggested edits 1/1,000 days/request * 1440 minutes/day = every 1.44 minutes.

- Enqueuing. This is `questions`, `edits`, and `reviews`, where content comes down a websocket. Rather than fetching the post immediately (which would be a massive waste of quota), posts are *enqueued* and then fetched in a batch once the queue gets to a certain size. To calculate this threshold, Inferno keeps a sliding-window average of the current post per minute rate over the past hour *across the network*. If the current posts per minute is, say, 15 posts/minute (not realistic), and the API allocation for the post type is 6,000 requests/day, then it will query the API once the queue *for a given site* reaches ceil(3 posts/minute / (6,000 requests/day / 1440 minutes/day)) = 4 requests enqueued.

Note that quota allocation is a global setting, not something that is set per bot.
