import Foundation

enum SpeciesCatalog {
    struct Defaults: Sendable {
        let calibration: Calibration
        let temperatureC: ClosedRange<Double>
        let humidityPct: ClosedRange<Double>
        let illuminanceLux: ClosedRange<Double>
    }

    static func defaults(for identifier: String) -> Defaults? {
        catalog[identifier]
    }

    private static let catalog: [String: Defaults] = [
        "monstera_deliciosa": .init(
            calibration: Calibration(soilDryPct: 30, soilWetPct: 70),
            temperatureC: 18...30, humidityPct: 50...80, illuminanceLux: 400...2000
        ),
        "epipremnum_aureum": .init(
            calibration: Calibration(soilDryPct: 25, soilWetPct: 65),
            temperatureC: 18...30, humidityPct: 40...70, illuminanceLux: 200...2000
        ),
        "sansevieria_trifasciata": .init(
            calibration: Calibration(soilDryPct: 15, soilWetPct: 50),
            temperatureC: 15...35, humidityPct: 30...60, illuminanceLux: 200...5000
        ),
        "chlorophytum_comosum": .init(
            calibration: Calibration(soilDryPct: 25, soilWetPct: 70),
            temperatureC: 15...27, humidityPct: 40...70, illuminanceLux: 300...3000
        ),
        "ficus_lyrata": .init(
            calibration: Calibration(soilDryPct: 30, soilWetPct: 65),
            temperatureC: 18...28, humidityPct: 40...65, illuminanceLux: 500...5000
        ),
        "spathiphyllum": .init(
            calibration: Calibration(soilDryPct: 30, soilWetPct: 75),
            temperatureC: 18...30, humidityPct: 50...80, illuminanceLux: 100...1000
        ),
        "aloe_vera": .init(
            calibration: Calibration(soilDryPct: 10, soilWetPct: 40),
            temperatureC: 15...35, humidityPct: 20...50, illuminanceLux: 1000...10000
        ),
        "hedera_helix": .init(
            calibration: Calibration(soilDryPct: 25, soilWetPct: 65),
            temperatureC: 10...22, humidityPct: 40...70, illuminanceLux: 200...2000
        ),
        "dracaena_fragrans": .init(
            calibration: Calibration(soilDryPct: 20, soilWetPct: 60),
            temperatureC: 18...30, humidityPct: 40...70, illuminanceLux: 200...3000
        ),
        "philodendron_hederaceum": .init(
            calibration: Calibration(soilDryPct: 25, soilWetPct: 65),
            temperatureC: 18...28, humidityPct: 50...80, illuminanceLux: 200...2000
        ),
        "zamioculcas_zamiifolia": .init(
            calibration: Calibration(soilDryPct: 10, soilWetPct: 45),
            temperatureC: 18...30, humidityPct: 30...60, illuminanceLux: 100...2000
        ),
        "ficus_elastica": .init(
            calibration: Calibration(soilDryPct: 25, soilWetPct: 60),
            temperatureC: 18...30, humidityPct: 40...70, illuminanceLux: 500...5000
        ),
        "calathea": .init(
            calibration: Calibration(soilDryPct: 35, soilWetPct: 75),
            temperatureC: 18...27, humidityPct: 60...90, illuminanceLux: 100...1000
        ),
        "crassula_ovata": .init(
            calibration: Calibration(soilDryPct: 10, soilWetPct: 40),
            temperatureC: 15...30, humidityPct: 20...50, illuminanceLux: 1000...10000
        ),
        "dieffenbachia": .init(
            calibration: Calibration(soilDryPct: 25, soilWetPct: 65),
            temperatureC: 18...30, humidityPct: 50...80, illuminanceLux: 200...2000
        ),
        "nephrolepis_exaltata": .init(
            calibration: Calibration(soilDryPct: 35, soilWetPct: 80),
            temperatureC: 15...27, humidityPct: 60...90, illuminanceLux: 100...1500
        ),
        "schefflera": .init(
            calibration: Calibration(soilDryPct: 25, soilWetPct: 60),
            temperatureC: 15...27, humidityPct: 40...70, illuminanceLux: 300...3000
        ),
        "tradescantia": .init(
            calibration: Calibration(soilDryPct: 25, soilWetPct: 65),
            temperatureC: 15...27, humidityPct: 40...70, illuminanceLux: 500...5000
        ),
        "begonia": .init(
            calibration: Calibration(soilDryPct: 30, soilWetPct: 70),
            temperatureC: 18...27, humidityPct: 50...80, illuminanceLux: 200...2000
        ),
        "peperomia": .init(
            calibration: Calibration(soilDryPct: 20, soilWetPct: 55),
            temperatureC: 18...27, humidityPct: 40...60, illuminanceLux: 200...2000
        ),
    ]

    static let commonNames: [String: String] = [
        "monstera_deliciosa": "Monstera",
        "epipremnum_aureum": "Pothos",
        "sansevieria_trifasciata": "Snake Plant",
        "chlorophytum_comosum": "Spider Plant",
        "ficus_lyrata": "Fiddle Leaf Fig",
        "spathiphyllum": "Peace Lily",
        "aloe_vera": "Aloe Vera",
        "hedera_helix": "English Ivy",
        "dracaena_fragrans": "Corn Plant",
        "philodendron_hederaceum": "Heartleaf Philodendron",
        "zamioculcas_zamiifolia": "ZZ Plant",
        "ficus_elastica": "Rubber Plant",
        "calathea": "Calathea",
        "crassula_ovata": "Jade Plant",
        "dieffenbachia": "Dumb Cane",
        "nephrolepis_exaltata": "Boston Fern",
        "schefflera": "Umbrella Plant",
        "tradescantia": "Wandering Jew",
        "begonia": "Begonia",
        "peperomia": "Peperomia",
    ]

    static let scientificNames: [String: String] = [
        "monstera_deliciosa": "Monstera deliciosa",
        "epipremnum_aureum": "Epipremnum aureum",
        "sansevieria_trifasciata": "Dracaena trifasciata",
        "chlorophytum_comosum": "Chlorophytum comosum",
        "ficus_lyrata": "Ficus lyrata",
        "spathiphyllum": "Spathiphyllum wallisii",
        "aloe_vera": "Aloe vera",
        "hedera_helix": "Hedera helix",
        "dracaena_fragrans": "Dracaena fragrans",
        "philodendron_hederaceum": "Philodendron hederaceum",
        "zamioculcas_zamiifolia": "Zamioculcas zamiifolia",
        "ficus_elastica": "Ficus elastica",
        "calathea": "Goeppertia spp.",
        "crassula_ovata": "Crassula ovata",
        "dieffenbachia": "Dieffenbachia seguine",
        "nephrolepis_exaltata": "Nephrolepis exaltata",
        "schefflera": "Schefflera actinophylla",
        "tradescantia": "Tradescantia zebrina",
        "begonia": "Begonia spp.",
        "peperomia": "Peperomia obtusifolia",
    ]
}
