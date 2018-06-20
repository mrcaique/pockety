pragma solidity ^0.4.22;

/// @title Journey contract.
contract Journey {

    enum StateType { In, Out }

    struct WorkerJourney {
        StateType state;
        uint realMinutes;
        uint computedMinutes;
        uint hourBank;
    }

    address private boss;

    SchedulerInterface constant scheduler = SchedulerInterface(0x6c8f2a135f6ed072de4503bd7c4999a1a17f824b);

    // Mapeamento de endereço do funcionário para registro do funcionário
    mapping(address => WorkerJourney) public records;

    constructor() public {
        boss = msg.sender;
    }

    // Registra a entrada do funcionário
    function enterRecord() public {
        // Validar alguma coisa aqui?
        require(records[msg.sender].state == StateType.OUT);
        records[msg.sender].state = StateType.IN;
        records[msg.sender].workMinutes = 0;
        // Fazer schedule para incrementar workMinutes a cada 5 blocos
        // Bloqueia por 1 minuto:
        uint lockedUntil = block.number + 5;
        // TODO: Verificar constantes aleatórias que não sei se devo mexer:
        uint[3] memory uintArgs = [
            200000,      // the amount of gas that will be sent with the txn.
            0,           // the amount of ether (in wei) that will be sent with the txn
            lockedUntil // the first block number on which the transaction can be executed.
        ];
        scheduler.scheduleTransaction(
            address(this),  // The address that the transaction will be sent to.
            "",             // The call data that will be sent with the transaction.
            255,            // The number of blocks this will be executable.
            uintArgs       // The tree args defined above
        );
    }

    function() {
        // Precisa incrementar o número de minutos que o trabalhador fez
        // Além de computar as horas extras usando os multiplicadores
        // configurados
        // TODO: Precisamos dar um jeito de pegar o worker correspondente
        require(records[worker].state == StateType.IN);
        records[worker].realMinutes = records[worker].realMinutes+1;
        if (records[worker].realMinutes > intervalo.min && records[worker].realMinutes < intervalo.max) {
            records[worker].computedMinutes += intervalo.multiplier;
        }
    }

    // Precisa ser chamado em algum momento....talvez no final do mês ou algo
    // assim
    function clearRecord() public {
        require(records[msg.sender].state == StateType.OUT);
        // TODO: Precisa PAGAR o que está no banco de horas
        // Precisa salvar apenas horas extras:
        records[msg.sender].hourBank = records[msg.sender].realMinutes - records[msg.sender].monthlyJourney;
        records[msg.sender].realMinutes = 0;
        records[msg.sender].computedMinutes = 0;
    }

    // Registra a saida do funcionário
    function leftRecord() public {
        // Validar alguma coisa aqui?
        require(records[msg.sender].state == StateType.IN);
        records[msg.sender].state = StateType.OUT;

        // schedule.cancel();
    }
}

contract WorkerContract {

    struct Worker {
        string name;
        string cpf;
        double hour_value;
        uint monthlyJourney;
    }

    mapping(address => Worker) private workers;

    address private boss;

    constructor() public {
        boss = msg.sender;
    }

    function createWorker(address worker, string name, string cpf, double hourValue, uint monthlyJourney) {
        require(msg.sender == boss);
        require(!workers[worker].name && !workers[worker].cpf);
        workers[worker] = Worker({
            name: name,
            cpf: cpf,
            work_value: workValue,
            monthlyJourney: monthlyJourney
        });
    }

    function editWorker(address worker, string name, string cpf, double hourValue, uint monthlyJourney) {
        require(msg.sender == boss);
        require(workers[worker].name && workers[worker].cpf);
        workers[worker].work_value = workValue;
        workers[worker].monthlyJourney = monthlyJourney;
    }

    function removeWorker(address worker, double hourValue, uint monthlyJourney) {
        require(msg.sender == boss);
        require(workers[worker].name && workers[worker].cpf);
        workers[worker].work_value = workValue;
        workers[worker].monthlyJourney = monthlyJourney;
    }
}

contract WorkMultiplier {

    struct Multiplier {
        uint min;
        uint max;
        uint multiplier;
    }

    mapping(address => Multiplier[]) private multipliers;

    address private boss;

    constructor() public {
        boss = msg.sender;
    }
}

contract SchedulerInterface {
    //
    // params:
    // - uintArgs[0] callGas
    // - uintArgs[1] callValue
    // - uintArgs[2] windowStart
    // - uint8 windowSize
    // - bytes callData
    // - address toAddress
    //
    function scheduleTransaction(address toAddress,
                                 bytes callData,
                                 uint8 windowSize,
                                 uint[3] uintArgs) public returns (address);
}
