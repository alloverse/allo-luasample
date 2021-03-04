local ffi = require("ffi")
local class = require('pl.class')
local gme = ffi.load("gme")

ffi.cdef([[
    typedef const char* gme_err_t;
    typedef struct Music_Emu Music_Emu;
    gme_err_t gme_open_file( const char path [], Music_Emu** out, int sample_rate );
    int gme_track_count( Music_Emu const* );
    gme_err_t gme_start_track( Music_Emu*, int index );
    gme_err_t gme_play( Music_Emu*, int count, short out [] );
    void gme_delete( Music_Emu* );
    gme_err_t gme_seek( Music_Emu*, int msec );
]])

function basename(str)
	return string.gsub(str, "(.*/)(.*)", "%2")
end


class.GmePlayer()
function GmePlayer:_init(path, track)
    local musicemuptr = ffi.new("Music_Emu*[1]")
    local status = gme.gme_open_file(path, musicemuptr, 48000)
    self.emu = musicemuptr[0]
    self.track = track
    self.isPaused = true
    self.trackCount = gme.gme_track_count(self.emu)
    self.name = basename(path)
    assert(self.trackCount > 0, "No tracks in file")
    gme.gme_start_track(self.emu, track)
end

function GmePlayer:setPaused(newPaused)
    self.isPaused = newPaused
end

function GmePlayer:reset()
    gme.gme_seek(self.emu, 0)
    self.isPaused = false
end

function GmePlayer:generateAudio(sampleCount)
    local interleaved = ffi.new("short[?]", sampleCount*2)
    local left = ffi.new("short[?]", sampleCount)
    local right = ffi.new("short[?]", sampleCount)
    if not self.isPaused then
        gme.gme_play(self.emu, sampleCount*2, interleaved);
    end
    for i = 0, sampleCount*2 - 1, 1 do
        local target = (i % 2 == 0) and left or right
        target[i/2] = interleaved[i]
    end
    return ffi.string(left, sampleCount*2), ffi.string(right, sampleCount*2)
end

class.TrackListPlayer()
function TrackListPlayer:_init()
    self.trackPlayers = {}
    self.currentTrack = 0
end

function TrackListPlayer:addTracksInFile(file)
    local gme = GmePlayer(file, 0)
    table.insert(self.trackPlayers, gme)
    for i = 1, gme.trackCount-1, 1 do
        local gme2 = GmePlayer(file, i)
        table.insert(self.trackPlayers, gme2)
    end
    if self.currentTrack == 0 then
        self.currentTrack = 1
    end
end

function TrackListPlayer:nextTrack()
    self.currentTrack = self.currentTrack + 1
    if self.currentTrack > #self.trackPlayers then
        self.currentTrack = 1
    end
    self:reset()
end

function TrackListPlayer:prevTrack()
    self.currentTrack = self.currentTrack - 1
    if self.currentTrack == 0 then
        self.currentTrack = self.trackCount
    end
    self:reset()
end

function TrackListPlayer:isPaused()
    local gme = self.trackPlayers[self.currentTrack]
    return gme.isPaused
end
function TrackListPlayer:setPaused(paused)
    local gme = self.trackPlayers[self.currentTrack]
    gme:setPaused(paused)
end
function TrackListPlayer:reset()
    local gme = self.trackPlayers[self.currentTrack]
    gme:reset()
end

function TrackListPlayer:generateAudio(sampleCount)
    local gme = self.trackPlayers[self.currentTrack]
    return gme:generateAudio(sampleCount)
end

function TrackListPlayer:currentTrackDescription()
    local gme = self.trackPlayers[self.currentTrack]
    if gme.trackCount > 1 then
        return gme.name .. "#".. tostring(gme.track)
    else
        return gme.name
    end
end

return {
    TrackListPlayer = TrackListPlayer,
    GmePlayer = GmePlayer
}