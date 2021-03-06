CREATE SCHEMA playout;

-- Representing playout, this is designed for a multi-channel playout system
--
-- YSTV probably doesn't need multi-channel, but I want to do multi-channel.
-- Ideally we'll have 4 24/7 streams:
-- * ystv public site (done by appointed person or by bot) Make sure content is "safe"
-- * ysmtv University produced only music
-- * ystv internal site (anyone can request, pop a random url or file. Doesn't have to be "safe"), OB behind the scenes cam, meetings, etc
-- * yusu (done by appointed person or bot) Mostly bar football, but also important streams
-- * university (done by appointed person or bot) mostly university signage, more
-- functionality for them, but we can use it for things like Roses
--
-- Linear streams will occur during things like Roses where we're covering different feeds.
--
-- We'll need to be able to auto generate the schedule
--
-- So when we're live you are always viewing it through a channel.
-- the channel has the global settings, then the schedule is the
-- building blocks of the channel. So, a schedule is what enables a
-- channel to be visible but you are interacting directly through the
-- channel. A channel can be multiple schedule files especially for
-- a 24/7 stream. But it can also be just one schedule item for a linear
-- event for example.
--
-- We don't give channel time information as it'll be generated from
-- the schedule. So in a sense a channel doesn't die? It just dissappears.
-- I suppose it's okay if a channel is deleted but for our playout schedule,
-- we'll still want to acknowledge where a video was originally played.
--
-- Do we need to know if it's linear?
-- Actually yes, it essentially lets the website know if its okay if a stream can be down.
-- i.e. we have a linear channel, content starts at 7pm so it's okay for no signal on it's
-- input until then and the website can display a non-video graphics with the schedule start.
-- 24/7 will trigger auto scheduler to ensure that there is always something on that
-- endpoint.
--
-- (will probably be renamed to constant / temporary, or something similar since it's all linear content,
-- however, we might also want to reference a constant stream has got it''s helper? Although, nothing stopping
-- the user having a helper on a temporary stream as well)
--
--
--
-- A channel is quite dumb, it'll accept anything chucked at it's input and will make it
-- watchable. The schedule provides a sprinkling of extra metadata which makes sense with
-- what is currently live.
--
-- So the schedule powers two things. The metadata presented to the public site NOT the content.
-- Then the auto scheduler bot "player". A streamer unit which reads the schedule and produces an output
-- accepted by the ingest_url.
--
-- A different element "Piper", which each channel will have an instance of. Will
-- attempt to ensure whatever is on the ingest_url matches the schedule. Effectively
-- Liquidsoap or Brave. This can be disabled and it removes the safety of the ingest url and makes
-- it fallible. But allows the streamer to play whatever they like without Piper
-- doing anything although since Piper isn't streaming it'll make swapping off from
-- the users broadcast difficult.
-- So manual should be used only for linear streams when we just don't have enough resources
-- to have complete auto scheduler coverage or we want to have a very low latency stream.
--
-- We might want an abstraction both above and below the schedule.
-- The above allows us to have a show lets say "top of 2020" and on the schedule, you'll
-- only see that, not the individual videos? Although you could say that it should be produced
-- as a video instead and rendered out as a single video?
--
-- The below 
--
-- We'll want to be able to group something so we could have content from a playlist
-- or something, but have specific idents to go along with it.
--
--
-- Not too sure how tight I want ystv's current vod database tied with this. I think I imagine the admin
-- interface allowing you to import and export from there, but obviously consistency might be a bit annoying.
-- Why would you do this? Well probably since we will have assets which don't belong on our vod infrastructure.
-- You might be concerned whether this will effect a general video retrieval since you could look at it like you
-- need to check two sources.

COMMENT ON SCHEMA playout IS
'Playout platform gives a flexible livestreaming platform.

Made of 5 blocks,
channel - The base object, and can optionally be extended on. Takes video from internal to public delivery
piper - Addon that will act as a proxy to channel''s ingest. Safety buffer and switching
player - Addon that takes VOD content and forwards it to piper
scheduler - Addon that directs piper to switch sources and player to play a programme
programme - A live source or a list of videos. Combined with scheduler''s playouts, makes an EPG';
--
-- create playout.channel
--
CREATE TABLE playout.channel(
    -- meta
    channel_id int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    short_name text NOT NULL UNIQUE,
    name text NOT NULL,
    description text NOT NULL DEFAULT '',
    type text NOT NULL,
    ingest_url text NOT NULL,
    ingest_type text NOT NULL,
    slate_url text NOT NULL,
    visibility text NOT NULL,
    has_scheduler bool NOT NULL DEFAULT true,
    has_piper bool NOT NULL DEFAULT true,

    -- inheritable default params for schedule
    archive bool NOT NULL DEFAULT TRUE,
    dvr bool NOT NULL DEFAULT TRUE,
    CONSTRAINT name_check CHECK (char_length(name) <= 20),
    CONSTRAINT desc_check CHECK (char_length(description) <= 240)
);
COMMENT ON TABLE playout.channel IS
'Base object of playout where optional modules can build more funcionality.
At this level it is capable of accepting an ingest and producing an output.
Producing DVR and handling an archive.
It doesn''t care about things like schedules or programmes.

Future plans include offering slate when ingest drops'; 

COMMENT ON COLUMN playout.channel.short_name IS
'Public facing path';

COMMENT ON COLUMN playout.channel.type IS
'linear / event. Linear for streams which do not end and event for temporary streams.';

COMMENT ON COLUMN playout.channel.ingest_url IS
'where we pull the video from, so this video that
is pulled is the product of the schedule.
E.g. Liquidsoap or OBS is generated a stream based on
schedule information and it''ll hit the ingest';

COMMENT ON COLUMN playout.channel.ingest_url IS
'rtmp/rtp/hls';

COMMENT ON COLUMN playout.channel.slate_url IS
'Fallback video if channel dies';

-- Might be depricating due to multiple outputs, and I think it could be compiled instead
-- of defined here since each output has a unique url
--COMMENT ON COLUMN playout.channel.playback_url IS
--'Resulting CMAF endpoint for watchers to view';

COMMENT ON COLUMN playout.channel.visibility IS
'combo box either:
public - will be visible on the public site,
internal - will be visible on the internal site,
private - only visible by url so unlisted';

COMMENT ON COLUMN playout.channel.archive IS
'Backup the ingest';

COMMENT ON COLUMN playout.channel.dvr IS
'Rewind support';

--
-- create playout.programmes
--
-- these are effectively the playout playbook instructions
CREATE TABLE playout.programmes(
    programme_id int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    title text NOT NULL,
    description text NOT NULL DEFAULT '',
    thumbnail text NOT NULL,
    type text NOT NULL,
    vod_url text NOT NULL DEFAULT '',
    CONSTRAINT title_check CHECK (char_length(title) <= 20),
    CONSTRAINT desc_check CHECK (char_length(description) <= 240)
);
COMMENT ON TABLE playout.programmes IS
'The programmes are either live sources or a list of videos. Executed by adding it
to the schedule.';

COMMENT ON COLUMN playout.programmes.description IS
'Length <= 240. Trying to keep it in similar look to EPG? If they want more, they
can use the VOD link';

-- Does handling something like a TV tuner require a different type to live?
COMMENT ON COLUMN playout.programmes.type IS
'vod / live';

-- We're using a URL incase we are playing the programme on our end but it ends up getting
-- hosted elsewhere. I.e. LA1 at Roses?
COMMENT ON COLUMN playout.programmes.vod_url IS
'VOD URL of programme, either set manually or scheduler/channel will set to latest version?';

CREATE TABLE playout.programme_videos (
    programme_video_id int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    programme_id int NOT NULL REFERENCES playout.programmes(programme_id) ON DELETE CASCADE,
    url text NOT NULL
);
COMMENT ON TABLE playout.programme_videos IS
'Used by player to play a selected bunch of videos in order. We have this 1-M relationship
since it allows us to re-use the same player, probably makes things stabler when you have a
lot of very short videos playing. Let''s you have a programme like 2016 hits and will show
that on the schedule and not each individual video making it look messy?';

--
-- create playout.schedule_playouts
--
-- Used by the scheduler to trigger the player to swap to the playout's
-- ingest.
-- Also used by public site to generate what to display to people.
CREATE TABLE playout.schedule_playouts(
    playout_id int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    channel_id int NOT NULL REFERENCES playout.channel(channel_id),
    programme_id int NOT NULL REFERENCES playout.programmes(programme_id),
    ingest_url text NOT NULL,
    ingest_type text NOT NULL,
    mark_in interval NOT NULL,
    mark_out interval NOT NULL,
    scheduled_start timestamptz NOT NULL,
    broadcast_start timestamptz,
    scheduled_end timestamptz NOT NULL,
    broadcast_end timestamptz,
    vod_url text NOT NULL DEFAULT '',
    -- properties optionally inherited from channel
    dvr bool NOT NULL DEFAULT TRUE,
    archive bool NOT NULL DEFAULT TRUE
);
COMMENT ON TABLE playout.schedule_playouts IS
'Playouts of video content used by the piper to playout to the ingest_url
which is either. If the programme is vod, scheduler will trigger player';

-- Might be depriciating due to programme's storing resulting videos?
-- Although it might be worthwhile separated since there could be the
-- possibility each playout is the same? i.e. If we're including adverts
-- in this VOD backup. Although is that going to happen?
-- It is dependent on how we define what a programme is. If a programme
-- is entirely unique and is going to produce the same output if it is executed
-- Otherwise we could have a looser definition where the output isn't the same
-- everytime. An example could be we have a programme which is essentially copy
-- this HLS live feed.
--
-- Programmes are supposed to be the recipe book of how to make that video, and
-- the result of that is a schedule_playout, so I'm saying that we store the video
-- in the schedule.
--
-- It might be worth to have a URL in both locations. Could have the live version
-- and the programme's preferred vod_url (an existing asset on the site?).
COMMENT ON COLUMN playout.schedule_playouts.vod_url IS
'If archive was enabled for playout (if not user set use channel''s default),
the outputted video asset. Usually a page featuring the video';

-- I suppose this doesn't need to be here since we could have someone stream directly
-- to piper. But thinking about it we'll want this to probably be someone unique so we
-- can have multiple sources at the ready then piper can select what it needs. Perhaps
-- if piper was disabled, then it will just be channel's ingest_url.
COMMENT ON COLUMN playout.schedule_playouts.ingest_url IS
'Where the broadcaster / player will stream to. The ingest_url will either be
* channel''s ingest_url (piper disabled)
* piper''s ingest_url (piper enabled).';

COMMENT ON COLUMN playout.schedule_playouts.ingest_type IS
'rtmp/rtp/hls';

-- Need to think about what triggers it the schedule_start or broadcast_start
-- schedule_start should be what the user set. Broadcast_start is what the scheduler
-- ended up produces after having to deal with the previous asset and any automatic shuffles.
COMMENT ON COLUMN playout.schedule_playouts.scheduled_start IS
'Triggers the video switch';

-- We could have it switch on programmme end by calling a finished
-- endpoint then using that to switch to the next item.
--
-- Perhaps a playout should have different types which
-- * float (will move when items overrun)
-- * static (when scheduled_start, begin)

-- Will add in later iterations
-- CREATE TABLE playout.idents(
--     ident_id int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
--     video_id int NOT NULL REFERENCES video.items(video_id) ON UPDATE CASCADE ON DELETE CASCADE
-- );

-- CREATE TABLE playout.ident_groups(
--     group_id int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY
-- );

-- CREATE TABLE playout.ident_group_items (
--     group_id int REFERENCES playout.ident_groups(group_id) ON UPDATE CASCADE ON DELETE CASCADE,
--     ident_id int REFERENCES playout.idents(ident_id) ON UPDATE CASCADE ON DELETE CASCADE,
--     CONSTRAINT ident_group_items_pkey PRIMARY KEY (group_id, ident_id)
-- );
CREATE TABLE playout.outputs(
    output_id int GENRATED BY DEFAULT AS IDENTITY ON UPDATE CASCADE ON DELETE CASCADE,
    channel_id int NOT NULL REFERENCES playout.channel(channel_id) ON UPDATE CASCADE ON DELETE CASCADE,
    name text NOT NULL,
    type text NOT NULL,
    passthrough bool NOT NULL,
    dvr bool NOT NULL,
    destination text NOT NULL,

    args text NOT NULL,

    CONSTRAINT outputs_pkey PRIMARY KEY (output_id, channel_id)
);

COMMNENT ON TABLE playout.outputs IS
'Outputs are the result of a channel. Channel''s can have multiple outputs of different types.';