-- Suppresses the "Frontlight intensity set to X" and "Warmth set to X"
-- notifications that appear when using gestures to change brightness
-- or warmth. These popups are slow to disappear and redundant when
-- plugins like Bookends already show the value less obtrusively.

local Device = require("device")

if Device:hasFrontlight() then
    local DeviceListener = require("device/devicelistener")

    -- Replace onShowIntensity with a no-op so the gesture handler
    -- (onChangeFlIntensity) still adjusts brightness but stays silent.
    function DeviceListener:onShowIntensity()
        return true
    end

    -- Replace onShowWarmth with a no-op so the gesture handler
    -- (onChangeFlWarmth) still adjusts warmth but stays silent.
    if Device:hasNaturalLight() then
        function DeviceListener:onShowWarmth()
            return true
        end
    end
end
