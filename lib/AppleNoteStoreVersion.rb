class AppleNoteStoreVersion

  attr_accessor :version_number,
                :platform

  VERSION_PLATFORM_IOS = 1
  VERSION_PLATFORM_MAC = 2

  IOS_VERSION_17 = 17
  IOS_VERSION_16 = 16
  IOS_VERSION_15 = 15
  IOS_VERSION_14 = 14
  IOS_VERSION_13 = 13
  IOS_VERSION_12 = 12
  IOS_VERSION_11 = 11
  IOS_VERSION_10 = 10
  IOS_VERSION_9 = 9
  IOS_LEGACY_VERSION = 8
  IOS_VERSION_UNKNOWN = -1

  def initialize(version_number=-1, platform=VERSION_PLATFORM_IOS)
    @platform = platform
    @version_number = version_number
  end

  def >(other)
    return @version_number > other.version_number
  end

  def <(other)
    return @version_number < other.version_number
  end

  def ==(other)
    return @version_number == other.version_number
  end

  def <=>(other)
    return @version_number <=> other.version_number
  end

  def same_platform(other)
    return @platform == other.platform
  end
end
