require 'spec_helper'

describe Journal do
  it "has a valid factory" do
    expect(build(:user)).to be_valid
  end
  let(:user) { build(:user) }
  let(:buddha) { create(:buddha) }
  let(:ananda) { create(:ananda) }

  describe "#latest_sit" do
    it "returns the latest sit for a user" do
      expect(buddha.latest_sit(buddha))
        .to eq [third_sit]
    end

    context 'private sit' do
      let(:private_sit) { create(:sit, :private, user: buddha) }

      it "returns private sit for owner" do
        expect(buddha.journal(buddha).latest_sit).to include private_sit
      end

      it "doesn't show for another user" do
        expect(buddha.journal(ananda).latest_sit).to_not include private_sit
      end
    end
  end

  describe "#sits_by_year" do
    it "returns all sits for a user for a given year" do
      expect(buddha.journal.sits_by_year(this_year))
        .to match_array(
          [first_sit, second_sit, third_sit]
        )
    end

    it "does not include sits outside of a given year" do
      expect(buddha.sits_by_year(this_year))
        .to_not include(fourth_sit)
    end
  end

  describe "#sits_by_month" do
    it "returns all sits for a user for a given month and year" do
      expect(buddha.sits_by_month(this_month, this_year))
        .to match_array(
          [first_sit, second_sit, third_sit]
        )
    end

    it "does not include sits outside of a given month and year" do
      expect(buddha.sits_by_month(this_month, this_year))
        .to_not include(fourth_sit)
    end
  end

  describe "#sat_on_date?" do
    before do
      create(:sit, created_at: Date.yesterday, user: buddha)
    end

    it "return true if user sat" do
      expect(buddha.sat_on_date?(Date.yesterday)).to eq(true)
    end

    it "return false if user didn't sit" do
      expect(buddha.sat_on_date?(Date.today - 2)).to eq(false)
    end
  end

  describe '#days_sat_in_date_range' do
    before do
      2.times do |i|
        create(:sit, created_at: Date.yesterday - i, user: buddha)
      end
      # The below shouldn't count towards total as buddha already sat that day
      create(:sit, created_at: Date.yesterday - 1, user: buddha)
    end
    it 'returns number of days' do
      expect(buddha.sits.count).to eq 3
      expect(buddha.days_sat_in_date_range(Date.yesterday - 3, Date.today)).to eq(2)
    end
  end

  describe "#time_sat_on_date" do
    it 'returns total minutes sat that day' do
      2.times do
        create(:sit, created_at: Date.today, user: buddha, duration: 20)
      end
      expect(buddha.time_sat_on_date(Date.today)).to eq(40)
    end
  end

  describe "#sat_for_x_on_date?" do
    before do
      create(:sit, created_at: Date.yesterday, user: buddha, duration: 30)
    end
    it 'returns true if user has sat x minutes that day' do
      expect(buddha.sat_for_x_on_date?(30, Date.yesterday)).to eq(true)
    end

    it 'returns false if user sat for less than x minutes that day' do
      expect(buddha.sat_for_x_on_date?(31, Date.yesterday)).to eq(false)
    end
  end

  describe "#days_sat_for_min_x_minutes_in_date_range" do
    it 'should return correct number of days' do
      2.times do |i|
        create(:sit, created_at: Date.today - i, user: buddha, duration: 30)
      end
      expect(buddha.days_sat_for_min_x_minutes_in_date_range(30, Date.today - 2, Date.today)).to eq 2
    end

    it 'should only return 1 when user sat twice on that day' do
      # Hard learned lesson: creating two sits programatically on the same day gives them both identical timestamps, which
      # when the function in question performs .uniq on a date range can give a very misleading pass when it should fail!
      # This could cause problems in all kinds of functions that work with dates. Hence + i.seconds to keep them unique.
      2.times do |i|
        create(:sit, created_at: Date.today + i.seconds, user: buddha, duration: 30)
      end

      expect(buddha.days_sat_for_min_x_minutes_in_date_range(30, Date.today, Date.today)).to eq 1
    end
  end
end