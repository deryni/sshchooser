#!/usr/bin/env busted

local pfns = dofile('parse_fns.lua')

-- Mock the bits of hammerspoon we need.
_G.hs = {
    styledtext = {
        new = function (s)
            return s
        end,
    },
    drawing = {
        color = {
            x11 = {
                gray = '',
            },
        },
    },
}

describe('config parsing', function ()
    it('should handle a missing ssh directory', function()
        local expected = {}
        local h, s = {}, {}
        local t = pfns.get_config_hosts(h, s, 'testdata/nosuchdir/config')
        assert.are.same(expected, t)
    end)

    it('should handle a missing file', function()
        local expected = {}
        local h, s = {}, {}
        local t = pfns.get_config_hosts(h, s, 'testdata/missing/config')
        assert.are.same(expected, t)
    end)

    it('should handle an empty file', function()
        local expected = {}
        local h, s = {}, {}
        local t = pfns.get_config_hosts(h, s, 'testdata/empty/config')
        assert.are.same(expected, t)
    end)

    it('should parse a simple file', function()
        local expected = {
            {text = 'devsys'},
        }
        local h, s = {}, {}
        local t = pfns.get_config_hosts(h, s, 'testdata/simple/config')
        assert.are.same(expected, t)
    end)

    it('should handle a canonical hostname', function()
        local expected = {
            {
                text = 'canonhost',
                hosts = {
                    'foo', 'bar',
                },
            }
        }
        local h, s = {}, {}
        local t = pfns.get_config_hosts(h, s, 'testdata/canonicalhost/config')
        assert.are.same(expected, t)
    end)

    it('should handle hostname tokens', function()
        local expected = {
            {text = 'spoon-r1.bigtech.com'},
            {text = 'spoon-r2.bigtech.com'}
        }
        local h, s = {}, {}
        local t = pfns.get_config_hosts(h, s, 'testdata/hostnametoken/config')
        assert.are.same(expected, t)
    end)

    it('should ignore wildcard hostnames', function()
        local expected = {
            {text = 'a'},
            {text = 'b'},
            {text = 'c'},
        }
        local h, s = {}, {}
        local t = pfns.get_config_hosts(h, s, 'testdata/wildcard/config')
        assert.are.same(expected, t)
    end)

    it('should extra handle leading, trailing, and middle spaces', function()
        local expected = {
            {
                text = 'leadcanon',
                hosts = {
                    'leadspace',
                },
            },
            {
                text = 'trailcanon',
                hosts = {
                    'trailspace',
                },
            },
            {
                text = 'bothcanon',
                hosts = {
                    'bothspace',
                },
            },
            {
                text = 'middlecanon',
                hosts = {
                    'middlespace',
                },
            },
        }
        local h, s = {}, {}
        local t = pfns.get_config_hosts(h, s, 'testdata/extraspaces/config')
        assert.are.same(expected, t)
    end)

    it('should parse User lines', function ()
        local expected = {
            {text = 'hostuser@somehost'},
            {text = 'otheruser@otherhost'},
            {text = 'midspaceuser@midspacehost'},
        }
        local h, s = {}, {}
        local t = pfns.get_config_hosts(h, s, 'testdata/user/config')
        assert.are.same(expected, t)
    end)

    it('should not duplicate hostnames', function()
        local expected = {
            {
                text = 'foobar',
                hosts = {
                    'foobar.tld',
                },
            },
            {
                text = 'baxx.tld',
                hosts = {
                    'baxx',
                },
            },
        }
        local h, s = {}, {}
        local t = pfns.get_config_hosts(h, s, 'testdata/duplicatehost/config')
        assert.are.same(expected, t)
    end)
end)

describe('known_host parsing', function ()
    it('should handle a missing ssh directory', function()
        local expected = {}
        local h, s = {}, {}
        local t = pfns.get_known_hosts(h, s, 'testdata/nosuchdir/known_hosts')
        assert.are.same(expected, t)
    end)

    it('should handle a missing file', function()
        local expected = {}
        local h, s = {}, {}
        local t = pfns.get_known_hosts(h, s, 'testdata/missing/known_hosts')
        assert.are.same(expected, t)
    end)

    it('should handle an empty file', function()
        local expected = {}
        local h, s = {}, {}
        local t = pfns.get_known_hosts(h, s, 'testdata/empty/known_hosts')
        assert.are.same(expected, t)
    end)

    it('should parse a simple file', function()
        local expected = {
            {text = '192.168.5.179'},
        }
        local h, s = {}, {}
        local t = pfns.get_known_hosts(h, s, 'testdata/simple/known_hosts')
        assert.are.same(expected, t)
    end)

    it('should ignore commented out lines', function()
        local expected = {
            {text = '192.168.1.179'},
            {text = '192.168.2.179'},
            {text = '192.168.3.179'},
        }
        local h, s = {}, {}
        local t = pfns.get_known_hosts(h, s, 'testdata/comments/known_hosts')
        assert.are.same(expected, t)
    end)

    it('should ignore wildcard hostnames', function()
        local expected = {
            {text = '192.168.5.179'},
            {text = '192.168.4.179'},
        }
        local h, s = {}, {}
        local t = pfns.get_known_hosts(h, s, 'testdata/wildcard/known_hosts')
        assert.are.same(expected, t)
    end)

    it('should ignore duplicate hosts', function()
        local expected = {
            {
                text = 'onlyonce',
                hosts = {
                    'newbutstill',
                },
            },
        }
        local h, s = {}, {}
        local t = pfns.get_known_hosts(h, s, 'testdata/duplicate/known_hosts')
        assert.are.same(expected, t)
    end)
end)

describe('combined parsing', function ()
    it('should handle a missing ssh directory', function()
        local expected = {}
        local t = pfns.parse_config('testdata/nosuchdir')
        assert.are.same(expected, t)
    end)

    it('should handle both files being missing', function()
        local expected = {}
        local t = pfns.parse_config('testdata/empty')
        assert.are.same(expected, t)
    end)

    it('should handle both files being empty', function()
        local expected = {}
        local t = pfns.parse_config('testdata/missing')
        assert.are.same(expected, t)
    end)

    it('should parse simple files', function()
        local expected = {
            {text = 'devsys'},
            {text = '192.168.5.179'},
        }
        local t = pfns.parse_config('testdata/simple')
        assert.are.same(expected, t)
    end)

    it('should handle full configs', function()
        local expected = {
            {text = 'devuser@devsys'},
            {
                text = 'flastname@host1.corp.bigtech.com',
                subText = 'host1',
            },
            {text = 'spoon-r1.bigtech.com'},
            {text = 'spoon-r2.bigtech.com'},
            {
                text = 'andme@canonhost',
                subText = 'foo bar andme additional add3',
            },
            {text = '192.168.5.179'},
            {
                text = '192.168.2.179',
                subText = '192.168.4.179',
            },
            {text = '192.168.3.179'},
            {text = '192.168.18.179'},
            {text = 'cahost'},
        }
        local t = pfns.parse_config('testdata/full')
        assert.are.same(expected, t)
    end)
end)

describe('reverse order parsing', function()
    it('should result in the same output', function()
        local expected = {
            {text = '192.168.5.179'},
            {
                text = '192.168.2.179',
                hosts = {
                    '192.168.4.179',
                },
            },
            {text = '192.168.3.179'},
            {
                text = 'andme@canonhost',
                hosts = {
                    'additional', 'add3', 'foo', 'bar', 'andme',
                },
            },
            {text = '192.168.18.179'},
            {text = 'cahost'},

            {text = 'devuser@devsys'},
            {
                text = 'flastname@host1.corp.bigtech.com',
                hosts = {
                    'host1',
                },
            },
            {text = 'spoon-r1.bigtech.com'},
            {text = 'spoon-r2.bigtech.com'},
        }
        local h, s = {}, {}
        local t = pfns.get_known_hosts(h, s, 'testdata/full/known_hosts')
        t = pfns.get_config_hosts(t, s, 'testdata/full/config')
        assert.are.same(expected, t)
    end)
end)
