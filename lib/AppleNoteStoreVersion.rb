class AppleNoteStoreVersion include Comparable

  attr_accessor :version_number,
                :platform

  VERSION_PLATFORM_IOS = 1
  VERSION_PLATFORM_MAC = 2

  IOS_VERSION_18 = 18
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

  def <=>(other)
    return @version_number <=> other if other.is_a? Integer
    return @version_number <=> other.version_number if other.is_a? AppleNoteStoreVersion
    return nil
  end

  def legacy?
    return @version_number == IOS_LEGACY_VERSION
  end

  def modern?
    return @version_number > IOS_LEGACY_VERSION
  end

  def unknown?
    return @version_number < 0
  end

  def same_platform(other)
    return @platform == other.platform
  end

  def to_s
    to_return = "#{@version_number}"
    to_return += " on Mac" if @platform == VERSION_PLATFORM_MAC
    return to_return
  end
end
