

## Logs

    Allow us to printn events to a special structure instead of a state variable.
    They cannot by accessed by smart contracts. Thats why they are cheaper

    Each event is tied to the smart contract or address that emitted the event.
    Platforms like chainlink and thegraph always listen for these events.

    Thegraph indexes these events so we can query them in a latter time.

    Example:

    event storedNumber(
        uint256 indexed oldNumber;
        uint256 indexed newNumber;
        uint256 addedNumber;
        address sender;
    )

    indexed parameters are also called Topics
    They much easier to find in a data structure.

    Events can have up to 3 indexed parameters.

    Emit:

        emit storedNumber(
            favoriteNumber,
            ....
        )


## Tests

forge coverage --report debug > coverage.txt


