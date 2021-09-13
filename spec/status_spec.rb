require_relative "../lib/status"

describe Lich::Status do
  Status = Lich::Status
  it "Status#parse" do
    status = Status.parse("(terrified, immobile)")
    expect(status)
      .to (include "terrified")
      .and (include "immobile")

    empty = Status.parse("")
    expect(empty)
      .to eq []

    # a giantman robber that is vulnerable
    verbose = Status.parse("that is vulnerable")
    expect(verbose)
      .to (include "vulnerable")
    
    expect(verbose.size)
      .to (eq 1)

    # a giantman robber that is vulnerable and is prone
    verbose = Status.parse("that is vulnerable and is prone")
    expect(verbose)
      .to eq %w(vulnerable prone)
  
    # a giantman robber that is vulnerable, appears immobilized, and is kneeling
    verbose = Status.parse("that is vulnerable, appears immobilized, and is kneeling")
    expect(verbose)
      .to eq %w(vulnerable immobilized kneeling)
  

    # a giantman robber that is stunned, dazed, bleeding, vulnerable, and is prone
    verbose = Status.parse("that is stunned, dazed, bleeding, vulnerable, and is prone")
    expect(verbose)
      .to eq %w(stunned dazed bleeding vulnerable prone)
  end
end