CREATE SCHEMA playout;

-- Representing playout, this is designed for a multi-channel playout system
--
-- YSTV probably doesn't need multi-channel, but I want to do multi-channel.
-- Ideally we'll have 4 24/7 streams:
-- * ystv public site (done by appointed person or by bot) Make sure content is "safe"
-- * ystv internal site (anyone can request, pop a random url or file. Doesn't have to be "safe")
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
-- A channel is quite dumb, it'll accept anything chucked at it's input and will make it
-- watchable. The schedule provides a sprinkling of extra metadata which makes sense with
-- what is currently live.
--
-- So the schedule powers two things. The metadata presented to the public site NOT the content.
-- Then the auto scheduler bot. A streamer unit which reads the schedule and produces an output
-- accepted by the ingest_url.
--
-- A different element auto scheduler, which each channel will have an instance of. Will
-- attempt to ensure whatever is on the ingest_url matches the schedule. Effectively
-- Liquidsoap. This can be disabled and it removes the safety of the ingest url and makes
-- it fallible. But allows the streamer to play whatever they like without auto scheduler
-- doing anything although since auto scheduler isn't streaming it'll make swapping off from
-- the users broadcast difficult, unless it is done through auto scheduler instead. So
-- manual should be used only for linear streams when we just don't have enough resources
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

CREATE TABLE playout.channel(
    -- meta
    channel_id int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    name text NOT NULL,
    description text NOT NULL,
    type text NOT NULL,
    origin_url text NOT NULL,
    slate_url text NOT NULL,
    playback_url text NOT NULL,
    visibility text NOT NULL,
    -- inheritable info for schedule
    archive bool NOT NULL DEFAULT TRUE,
    dvr bool NOT NULL DEFAULT TRUE
);

COMMENT ON COLUMN playout.channel(type) IS
'24/7 or linear. So if we still wanted our main stream 24/7 but we''ve also got a one off B stream';
COMMENT ON COLUMN playout.channel(origin_url) IS
'where we pull the video from, so this video that
is pulled is the product of the schedule.
E.g. Liquidsoap or OBS is generated a stream based on
schedule information and it''ll hit the origin';
COMMENT ON COLUMN playout.channel(slate_url) IS
'Fallback video if channel dies';
COMMENT ON COLUMN playout.channel(playback_url) IS
'Resulting CMAF endpoint for watchers to view';
COMMENT ON COLUMN playout.channel(visibility) IS
'combo box either:
public - will be visible on the public site,
internal - will be visible on the internal site,
private - only visible by url so unlisted';
--
-- create playout.schedule
--
-- this is used by public site to generate what to display to people.
-- it is also used by the scheduler as a job.
CREATE TABLE playout.schedule(
    schedule_id int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    channel_id int NOT NULL REFERENCES playout.channel(channel_id),
    programme_id REFERENCES video.programmes(programme_id),
    ingest_url text NOT NULL,
    scheduled_start timestamptz NOT NULL,
    broadcast_start timestamptz,
    scheduled_end timestamptz NOT NULL,
    broadcast_end timestamptz,
    -- properties optionally inherited from channel
    name text NOT NULL,
    archive bool NOT NULL DEFAULT TRUE
);

COMMENT ON COLUMN playout.schedule(video_id) IS
'If archive was enabled for release, this would be a url to where to watch it.
So either a ystv url to it, or an external link?';

--
-- create playout.programmes
--
-- these are effectively the playout playbook instructions
CREATE TABLE playout.programmes(
    programme_id int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    title text NOT NULL,
    description text NOT NULL,
    thumbnail text NOT NULL
);

CREATE TABLE playout.programme_videos (
    programme_video_id int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    programme_id int NOT NULL REFERENCES playout.programmes(programe_id) ON DELETE CASCADE,
    url text NOT NULL
);

CREATE TABLE playout.idents(
    ident_id int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    video_id int NOT NULL REFERENCES video.items(video_id) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE playout.ident_groups(
    group_id int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY
);

CREATE TABLE playout.ident_group_items (
    group_id int REFERENCES playout.ident_groups(group_id) ON UPDATE CASCADE ON DELETE CASCADE,
    ident_id int REFERENCES playout.idents(ident_id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT ident_group_items_pkey PRIMARY KEY (group_id, ident_id)
);
