pragma solidity ^0.4.22;

/// @title Journey contract.
contract Journey {

    enum Type { Input, Output }

    struct Record {
        Type type;
        uint ts;
    }

    // Precisamos da lista de chefes?
    // Sim.
    // Lista de chefes da empresa
    address[] public bosses;

    // Mapeamento de endereço do funcionário para lista de registros
    mapping(address => Record[]) public records;

    constructor(address[] _bosses) public {
        bosses = _bosses;
        // Entrar com a Lista de funcionários autorizado? Não sei
    }

    // Registra a entrada do funcionário
    function enterRecord() public {
        // Validar alguma coisa aqui?
        // Ideia: Validar se o usuário saiu antes de entrar
        records[msg.sender].push(Record({
            type: Input,
            ts: now
        }));
    }

    // Registra a saida do funcionário
    function leftRecord() public {
        // Validar alguma coisa aqui?
        // Ideia: Validar se o usuário entrou antes de sair
        records[msg.sender].push(Record({
            type: Output,
            ts: now
        }));
    }

    // Retorna registros de entrada e saída de cada funcionário
    function getRecords(address worker) public view
            returns (Record[] workers)
    {
        // Validar se é um chefe aqui?
        workers = records[worker];
    }
}
