pragma Singleton
import QtQuick

QtObject {
	readonly property color background: "#0B0C0F"
	readonly property color surface: "#17191E"
	readonly property color glass: "#B8202329"

	readonly property color primary: "#F4F5F7"
	readonly property color secondary: "#9297A2"

	readonly property color cyan: "#76DDEB"
	readonly property color orange: "#F0A36B"

	readonly property int radiusSmall: 12
	readonly property int radiusMedium: 20
	readonly property int radiusLarge: 30

	readonly property int animationFast: 140
	readonly property int animationNormal: 260
	readonly property int animationSlow: 450
}
