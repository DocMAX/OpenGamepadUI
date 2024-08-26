//! # D-Bus interface proxy for: `org.bluez.Adapter1`
//!
//! This code was generated by `zbus-xmlgen` `4.1.0` from D-Bus introspection data.
//! Source: `Interface '/org/bluez/hci0' from service 'org.bluez' on system bus`.
//!
//! You may prefer to adapt it, instead of using it verbatim.
//!
//! More information can be found in the [Writing a client proxy] section of the zbus
//! documentation.
//!
//! This type implements the [D-Bus standard interfaces], (`org.freedesktop.DBus.*`) for which the
//! following zbus API can be used:
//!
//! * [`zbus::fdo::IntrospectableProxy`]
//! * [`zbus::fdo::PropertiesProxy`]
//!
//! Consequently `zbus-xmlgen` did not generate code for the above interfaces.
//!
//! [Writing a client proxy]: https://dbus2.github.io/zbus/client.html
//! [D-Bus standard interfaces]: https://dbus.freedesktop.org/doc/dbus-specification.html#standard-interfaces,
use zbus::proxy;
#[proxy(
    interface = "org.bluez.Adapter1",
    default_service = "org.bluez",
    default_path = "/org/bluez/hci0"
)]
trait Adapter1 {
    /// GetDiscoveryFilters method
    fn get_discovery_filters(&self) -> zbus::Result<Vec<String>>;

    /// RemoveDevice method
    fn remove_device(&self, device: &zbus::zvariant::ObjectPath<'_>) -> zbus::Result<()>;

    /// SetDiscoveryFilter method
    fn set_discovery_filter(
        &self,
        properties: std::collections::HashMap<&str, &zbus::zvariant::Value<'_>>,
    ) -> zbus::Result<()>;

    /// StartDiscovery method
    fn start_discovery(&self) -> zbus::Result<()>;

    /// StopDiscovery method
    fn stop_discovery(&self) -> zbus::Result<()>;

    /// Address property
    #[zbus(property)]
    fn address(&self) -> zbus::Result<String>;

    /// AddressType property
    #[zbus(property)]
    fn address_type(&self) -> zbus::Result<String>;

    /// Alias property
    #[zbus(property)]
    fn alias(&self) -> zbus::Result<String>;
    #[zbus(property)]
    fn set_alias(&self, value: &str) -> zbus::Result<()>;

    /// Class property
    #[zbus(property)]
    fn class(&self) -> zbus::Result<u32>;

    /// Discoverable property
    #[zbus(property)]
    fn discoverable(&self) -> zbus::Result<bool>;
    #[zbus(property)]
    fn set_discoverable(&self, value: bool) -> zbus::Result<()>;

    /// DiscoverableTimeout property
    #[zbus(property)]
    fn discoverable_timeout(&self) -> zbus::Result<u32>;
    #[zbus(property)]
    fn set_discoverable_timeout(&self, value: u32) -> zbus::Result<()>;

    /// Discovering property
    #[zbus(property)]
    fn discovering(&self) -> zbus::Result<bool>;

    /// ExperimentalFeatures property
    #[zbus(property)]
    fn experimental_features(&self) -> zbus::Result<Vec<String>>;

    /// Manufacturer property
    #[zbus(property)]
    fn manufacturer(&self) -> zbus::Result<u16>;

    /// Modalias property
    #[zbus(property)]
    fn modalias(&self) -> zbus::Result<String>;

    /// Name property
    #[zbus(property)]
    fn name(&self) -> zbus::Result<String>;

    /// Pairable property
    #[zbus(property)]
    fn pairable(&self) -> zbus::Result<bool>;
    #[zbus(property)]
    fn set_pairable(&self, value: bool) -> zbus::Result<()>;

    /// PairableTimeout property
    #[zbus(property)]
    fn pairable_timeout(&self) -> zbus::Result<u32>;
    #[zbus(property)]
    fn set_pairable_timeout(&self, value: u32) -> zbus::Result<()>;

    /// PowerState property
    #[zbus(property)]
    fn power_state(&self) -> zbus::Result<String>;

    /// Powered property
    #[zbus(property)]
    fn powered(&self) -> zbus::Result<bool>;
    #[zbus(property)]
    fn set_powered(&self, value: bool) -> zbus::Result<()>;

    /// Roles property
    #[zbus(property)]
    fn roles(&self) -> zbus::Result<Vec<String>>;

    /// UUIDs property
    #[zbus(property, name = "UUIDs")]
    fn uuids(&self) -> zbus::Result<Vec<String>>;

    /// Version property
    #[zbus(property)]
    fn version(&self) -> zbus::Result<u8>;
}
