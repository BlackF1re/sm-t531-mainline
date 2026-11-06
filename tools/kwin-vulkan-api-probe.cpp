#include <expected>
#include <utility>
#include <vulkan/vulkan_raii.hpp>
template<class T> constexpr bool hasResultValue = requires(T &value) {
    value.result;
    value.value;
};
static_assert(hasResultValue<decltype(std::declval<vk::raii::Context>().createInstance(std::declval<vk::InstanceCreateInfo>()))>);
static_assert(hasResultValue<decltype(std::declval<vk::raii::Instance>().enumeratePhysicalDevices())>);
static_assert(hasResultValue<decltype(std::declval<vk::raii::PhysicalDevice>().enumerateDeviceExtensionProperties())>);
static_assert(hasResultValue<decltype(std::declval<vk::raii::PhysicalDevice>().createDevice(std::declval<vk::DeviceCreateInfo>()))>);
