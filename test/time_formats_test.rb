require "test_helper"

class TimeFormatsTest < ActiveSupport::TestCase
  FIXED_TIME = Time.utc(2026, 3, 7, 4, 5, 6)

  test "job_harbor_timestamp_with_zone renders date, time and zone" do
    assert_equal "2026-03-07 04:05:06 UTC", FIXED_TIME.to_fs(:job_harbor_timestamp_with_zone)
  end

  test "job_harbor_timestamp renders date and time without zone" do
    assert_equal "2026-03-07 04:05:06", FIXED_TIME.to_fs(:job_harbor_timestamp)
  end

  test "job_harbor_short renders abbreviated month, day and time" do
    assert_equal "Mar 07, 04:05:06", FIXED_TIME.to_fs(:job_harbor_short)
  end

  test "formats render the same for ActiveSupport::TimeWithZone" do
    time = FIXED_TIME.in_time_zone("Eastern Time (US & Canada)")

    assert_equal "2026-03-06 23:05:06 EST", time.to_fs(:job_harbor_timestamp_with_zone)
    assert_equal "Mar 06, 23:05:06", time.to_fs(:job_harbor_short)
  end

  test "every registered key carries the job_harbor prefix" do
    assert_not_empty JobHarbor::TimeFormats::FORMATS
    assert JobHarbor::TimeFormats::FORMATS.keys.all? { |key| key.to_s.start_with?("job_harbor_") }
  end

  test "register keeps a job_harbor format the host app already set" do
    original = Time::DATE_FORMATS.dup
    Time::DATE_FORMATS[:job_harbor_short] = "%H host override"

    JobHarbor::TimeFormats.register

    assert_equal "04 host override", FIXED_TIME.to_fs(:job_harbor_short)
  ensure
    Time::DATE_FORMATS.replace(original)
  end

  test "engine boot registers the formats on Time::DATE_FORMATS without changing :db" do
    JobHarbor::TimeFormats::FORMATS.each do |key, format|
      assert_equal format, Time::DATE_FORMATS[key]
    end
    assert_equal "%Y-%m-%d %H:%M:%S", Time::DATE_FORMATS[:db]
  end
end
