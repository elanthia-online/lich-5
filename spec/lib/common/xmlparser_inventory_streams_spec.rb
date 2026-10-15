# frozen_string_literal: true

require_relative '../../spec_helper'
require 'ox'
require 'common/gameobj'
require 'common/xmlparser'

# Worn-items and stow-container streams, through the real GameObj.
#
# The Saga-identity stream (Frontend::CLIENT_STRING since #1700) links every
# item in both. Like GemStone, it sends <container id='stow' target=...> at
# login; a parser that missed the login (the replay fixtures, whose login is
# synthetic) has only the feed's header line to name the stow container. Shapes
# are verbatim from DR captures (ids kept) unless an example says otherwise; the
# legacy dialect sends the same streams as plain text.
RSpec.describe 'Lich::Common::XMLParser inventory streams' do
  subject(:parser) { Lich::Common::XMLParser.new }

  let(:gameobj) { Lich::Common::GameObj }

  def feed(*lines)
    lines.each { |l| Ox.sax_parse(parser, l, convert_special: false, symbolize: false, skip: :skip_none) }
  end

  def stow_refresh(container_id, *items)
    header = %(<inv id='stow'>In the <a exist="#{container_id}" noun="pack">pack</a>:</inv>)
    body = items.map { |id, noun, name| %(<inv id='stow'> a <a exist="#{id}" noun="#{noun}">#{name}</a></inv>) }.join
    %(<clearContainer id="stow"/>#{header}#{body})
  end

  prompt = '<prompt time="1792032136">&gt;</prompt>'

  def worn_list(*items)
    ["<clearStream id='inv' ifClosed=''/><pushStream id='inv'/>Your worn items are:"] +
      items.map { |id, noun, name| %(  a <a exist="#{id}" noun="#{noun}">#{name}</a>) } +
      ['<popStream/>']
  end

  before do
    allow(XMLData).to receive(:game).and_return('DR')
    parser.instance_variable_set(:@game, 'DR')
    gameobj.clear_inv
    gameobj.clear_all_containers
  end

  def contents(id)
    (gameobj.containers[id] || []).map(&:noun)
  end

  def worn
    (gameobj.inv || []).map(&:noun)
  end

  describe 'stow container (DragonRealms, no <container id=stow> seen)' do
    it "learns the stow container from its header on the first refresh and files the items under it" do
      feed(stow_refresh('195648378', %w[195648534 nugget massive\ copper\ nugget], %w[195648529 pouch soft\ gem\ pouch]), prompt)

      expect(parser.stow_container_id).to eq('195648378')
      expect(contents('195648378')).to eq(%w[nugget pouch])
      expect(worn).to be_empty
    end

    it 'does not publish an empty container keyed nil' do
      feed(stow_refresh('195648378', %w[195648534 nugget nugget]), prompt)
      expect(gameobj.containers.keys).to eq(['195648378'])
    end

    it 'replaces the contents on the next refresh (an item put away is gone)' do
      feed(stow_refresh('195648378', %w[1 nugget nugget], %w[2 pouch pouch]), prompt)
      feed(stow_refresh('195648378', %w[2 pouch pouch]), prompt)

      expect(contents('195648378')).to eq(%w[pouch])
    end

    it 'follows a change of stow container' do
      feed(stow_refresh('195648378', %w[1 nugget nugget]), prompt)
      feed(stow_refresh('200000001', %w[3 gem gem]), prompt)

      expect(parser.stow_container_id).to eq('200000001')
      expect(contents('200000001')).to eq(%w[gem])
      # The refresh opened under the old id at clearContainer is abandoned, not
      # published empty: the old container keeps its last known contents.
      expect(contents('195648378')).to eq(%w[nugget])
    end

    it 'replaces contents already known for the container on the refresh that first names it' do
      # e.g. filled by an INV LIST before the stow container id was learned
      gameobj.new_inv('1', 'nugget', 'nugget', '195648378')
      gameobj.new_inv('2', 'pouch', 'pouch', '195648378')
      feed(stow_refresh('195648378', %w[2 pouch pouch]), prompt)

      expect(contents('195648378')).to eq(%w[pouch])
    end

    it 'replaces the contents of a stow container it returns to' do
      feed(stow_refresh('195648378', %w[1 nugget nugget], %w[2 pouch pouch]), prompt)
      feed(stow_refresh('200000001', %w[3 gem gem]), prompt)
      feed(stow_refresh('195648378', %w[2 pouch pouch]), prompt)

      expect(contents('195648378')).to eq(%w[pouch])
      expect(contents('200000001')).to eq(%w[gem])
    end

    it 'deletes the container when its header reports it closed' do
      feed(stow_refresh('195648378', %w[1 nugget nugget]), prompt)
      feed(%(<clearContainer id="stow"/><inv id='stow'>The <a exist="195648378" noun="pack">pack</a> is closed.</inv>), prompt)

      expect(gameobj.containers).not_to have_key('195648378')
    end

    it 'leaves the legacy plain-text stow feed alone' do
      feed(%(<clearContainer id="stow"/><inv id='stow'>In the pack:</inv><inv id='stow'> a soft gem pouch</inv>), prompt)

      expect(parser.stow_container_id).to be_nil
      expect(gameobj.containers).to be_empty
      expect(worn).to be_empty
    end

    it "keeps GemStone's authoritative <container id='stow'> even when a header names another container" do
      allow(XMLData).to receive(:game).and_return('GS')
      parser.instance_variable_set(:@game, 'GS')
      feed(%(<container id='stow' title='My Backpack' target='#7001' location='right' save='' resident='true'/>))
      feed(stow_refresh('9999', %w[1 gem gem]), prompt)

      expect(parser.stow_container_id).to eq('7001')
      expect(gameobj.containers.keys).to eq(['7001'])
    end
  end

  describe "stow container (DragonRealms after a login's <container id=stow>)" do
    login_tag = %(<container id='stow' title='My Pack' target='#195648378' location='right' save='' resident='true'/>)

    it 'files the stow refresh under the container the tag names' do
      feed(login_tag, stow_refresh('195648378', %w[1 nugget nugget]), prompt)

      expect(parser.stow_container_id).to eq('195648378')
      expect(contents('195648378')).to eq(%w[nugget])
      expect(worn).to be_empty
    end

    it 'files a feed whose header names another container under that container, not the stow container' do
      # e.g. a pack another character handed over, held in hand: the stow feed
      # lists it under its own header
      feed(login_tag, stow_refresh('195648378', %w[1 nugget nugget]), prompt)
      feed(stow_refresh('200000002', %w[5 almanac almanac], %w[6 skates skates]), prompt)

      expect(parser.stow_container_id).to eq('195648378')
      expect(contents('195648378')).to eq(%w[nugget])
      expect(contents('200000002')).to eq(%w[almanac skates])

      feed(stow_refresh('195648378', %w[1 nugget nugget], %w[7 gem gem]), prompt)
      expect(contents('195648378')).to eq(%w[nugget gem])
    end
  end

  describe 'worn items list' do
    it 'replaces worn inventory on each linked list (an item removed is gone)' do
      feed(*worn_list(%w[195648608 helm helm], %w[195648607 mask mask]))
      feed(*worn_list(%w[195648608 helm helm]))

      expect(worn).to eq(%w[helm])
    end

    it 'never publishes an INV LIST scrape that is still in flight' do
      # A linked list first, so the parser knows the stream links items and the
      # in-flight guard (not the legacy-dialect check) is what keeps it out.
      feed(*worn_list(%w[1 cloak cloak])) # previously published
      expect(parser.stream_feature?(:links)).to be true
      gameobj.begin_inv # an INV LIST scrape owns the worn staging
      gameobj.new_inv('2', 'helm', 'a helm')
      feed(*worn_list(%w[3 mask mask]))

      expect(gameobj.inv_refresh_open?).to be true
      expect(worn).to eq(%w[cloak]) # still the published list
      gameobj.commit_inv
      expect(worn).to contain_exactly('helm', 'mask')
    end

    it 'forgets its own worn refresh at a reset, so a later list cannot publish an INV LIST scrape' do
      feed(*worn_list(%w[1 cloak cloak])) # previously published
      feed("<clearStream id='inv' ifClosed=''/><pushStream id='inv'/>Your worn items are:",
           '  a <a exist="2" noun="helm">helm</a>') # cut off before its popStream
      parser.reset # parse-error recovery discards the half-filled refresh
      gameobj.begin_inv # an INV LIST scrape then owns the worn staging
      gameobj.new_inv('3', 'boots', 'some boots')
      feed(*worn_list(%w[4 mask mask]))

      expect(gameobj.inv_refresh_open?).to be true
      expect(worn).to eq(%w[cloak])
      gameobj.commit_inv
    end

    it 'gives up its worn refresh once it commits it, so a later list cannot publish an INV LIST scrape' do
      feed(*worn_list(%w[1 cloak cloak])) # links the stream
      feed(*worn_list(%w[2 helm helm])) # a staged refresh the parser opens and commits itself
      expect(worn).to eq(%w[helm])
      gameobj.begin_inv # an INV LIST scrape then owns the worn staging
      gameobj.new_inv('3', 'boots', 'some boots')
      feed(*worn_list(%w[4 mask mask]))

      expect(gameobj.inv_refresh_open?).to be true
      expect(worn).to eq(%w[helm])
      gameobj.commit_inv
    end

    it 'stages the first linked list of a session, before any link has been seen' do
      # At a real login the first worn list's pushStream precedes the stream's
      # first <a exist>, so the dialect is not known yet when it opens.
      gameobj.new_inv('1', 'cloak', 'a wool cloak') # stale worn entry
      expect(parser.stream_feature?(:links)).to be false
      feed(*worn_list(%w[2 helm helm]))

      expect(worn).to eq(%w[helm])
    end

    it 'leaves an INV LIST scrape alone on a first linked list' do
      gameobj.begin_inv # an INV LIST scrape owns the worn staging
      gameobj.new_inv('3', 'boots', 'some boots')
      feed(*worn_list(%w[4 mask mask]))

      expect(gameobj.inv_refresh_open?).to be true
      expect(worn).to be_empty
      gameobj.commit_inv
      expect(worn).to contain_exactly('boots', 'mask')
    end

    it 'leaves an INV LIST scrape alone that opens while a first linked list waits for its first link' do
      gameobj.new_inv('1', 'cloak', 'a wool cloak') # previously published
      head, *rest = worn_list(%w[4 mask mask])
      feed(head)
      gameobj.begin_inv # an INV LIST scrape takes the worn staging first
      gameobj.new_inv('3', 'boots', 'some boots')
      feed(*rest)

      expect(gameobj.inv_refresh_open?).to be true
      expect(worn).to eq(%w[cloak])
      gameobj.commit_inv
    end

    it 'opens no worn refresh for the legacy plain-text list' do
      gameobj.new_inv('1', 'cloak', 'a wool cloak')
      feed("<clearStream id='inv' ifClosed=''/><pushStream id='inv'/>Your worn items are:", '  a wool cloak', '<popStream/>')

      expect(worn).to eq(%w[cloak])
    end
  end
end
